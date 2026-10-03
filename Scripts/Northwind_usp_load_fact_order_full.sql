/*
=========================================================================================
Project:        Northwind Data Warehouse
Layer:          DDS - Sales Data Mart
Object Name:    sale.usp_load_fact_order_full
Author:         Reza Afkhamnia
Description:    Performs a Full Load for the Sales Order Fact table.

                Full Load Strategy:
                1. Deletes all records from sale.fact_order.
                2. Extracts Order Headers and Order Details from Stage.
                3. Applies data quality transformations.
                4. Resolves Dimension Surrogate Keys.
                5. Maps Gregorian dates to the shared Date Dimension.
                6. Inserts transformed rows at the defined Fact grain.

                Fact Grain:
                One row per Order ID + Product ID.

                Date Dimension:
                [dds].[dbo].[dim_date]

                Date Lookup:
                Stage Order Date -> dim_date.MiladiDate
                Stored Fact Key  -> dim_date.MiladiDateKey

                Transformation Techniques Demonstrated:
                1.  Deduplication
                2.  Filtering (Rows and Columns)
                3.  Cleaning and Mapping
                4.  Value Standardization
                5.  Joining
                6.  Aggregation
                7.  Deriving New Values
                8.  Remove Unwanted Space
                9.  Handling Missing Values

Prerequisite:   EXEC sale.usp_load_dim_northwind;
Execution:      EXEC sale.usp_load_fact_order_full;
=========================================================================================
*/

USE dds;
GO

CREATE OR ALTER PROCEDURE sale.usp_load_fact_order_full
AS
BEGIN

    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @load_datetime DATETIME2(3) = SYSUTCDATETIME();

    BEGIN TRY
        BEGIN TRANSACTION;

        ---------------------------------------------------------------------------------
        -- 1. FULL LOAD
		-- All existing Fact records are removed before rebuilding the Fact table.
        ---------------------------------------------------------------------------------

        TRUNCATE TABLE sale.fact_order;
        ;WITH order_ranked AS
        (
            /*
                Deduplication:
                Keeps the latest Stage record for each order_id.
            */

            SELECT
                order_id,
                customer_id,
                employee_id,
                order_date,
                required_date,
                shipped_date,
                ship_via,
                freight,
                dwh_inserted_at,

                ROW_NUMBER() OVER
                (
                    PARTITION BY order_id
                    ORDER BY dwh_inserted_at DESC
                ) AS row_number_value

            FROM stage_dw.stage.northwind_orders

            WHERE order_id IS NOT NULL
        ),


        orders_cleaned AS
        (
            /*
                Data Cleaning:
                - Customer ID is trimmed.
                - Dates are converted to DATE.
                - Freight NULL values become zero.
                Shipping Geography is intentionally NOT used here.
                Reason:
                The new Snowflake model does not connect Fact Order
                directly to Dim Geography.
            */

            SELECT

                order_id,
                LTRIM(RTRIM(customer_id)) AS customer_id,
                employee_id,
                ship_via,
                CAST(order_date AS DATE) AS order_date,
                CAST(required_date AS DATE) AS required_date,
                CAST(shipped_date AS DATE) AS shipped_date,
                COALESCE
                (
                    CAST(freight AS DECIMAL(19,4)),
                    0
                ) AS freight_amount

            FROM order_ranked
            WHERE row_number_value = 1
        ),

        line_ranked AS
        (
            /*
                Deduplication:
                Keeps the latest Stage row for each:
                    order_id + product_id
            */

            SELECT

                order_id,
                product_id,
                unit_price,
                quantity,
                discount,
                dwh_inserted_at,

                ROW_NUMBER() OVER
                (
                    PARTITION BY
                        order_id,
                        product_id

                    ORDER BY
                        dwh_inserted_at DESC

                ) AS row_number_value

            FROM stage_dw.stage.northwind_order_details
            WHERE order_id IS NOT NULL
              AND product_id IS NOT NULL
        ),

        lines_cleaned AS
        (
            /*
                Data Cleaning:
                Missing unit price -> 0
                Missing quantity   -> 0
                Discount is standardized into [0,1].
            */

            SELECT

                order_id,
                product_id,
                COALESCE
                (
                    CAST(unit_price AS DECIMAL(19,4)),
                    0
                ) AS unit_price,
                COALESCE
                (
                    CAST(quantity AS INT),
                    0
                ) AS quantity,

                CASE
                    WHEN COALESCE
                    (
                        CAST(discount AS DECIMAL(9,6)),
                        0
                    ) < 0
                    THEN 0

                    WHEN COALESCE
                    (
                        CAST(discount AS DECIMAL(9,6)),
                        0
                    ) > 1
                    THEN 1

                    ELSE COALESCE
                    (
                        CAST(discount AS DECIMAL(9,6)),
                        0
                    )

                END AS discount_rate

            FROM line_ranked
            WHERE row_number_value = 1
        ),

        order_line_aggregated AS
        (
            /*
                Fact Grain:
                    One row per Order ID + Product ID
                Aggregation protects the warehouse against accidental duplicate source records.
            */

            SELECT

                order_id,
                product_id,
                MAX(unit_price) AS unit_price,
                SUM(quantity) AS quantity,
                MAX(discount_rate) AS discount_rate

            FROM lines_cleaned
            GROUP BY
                order_id,
                product_id
        )

        INSERT INTO sale.fact_order
        (
            order_id,
            source_product_id,
            customer_key,
            employee_key,
            product_key,
            shipper_key,
            order_date_key,
            required_date_key,
            shipped_date_key,
            unit_price,
            quantity,
            discount_rate,
            gross_amount,
            discount_amount,
            net_amount,
            freight_amount,
            dwh_inserted_at
        )


        SELECT
            o.order_id,
            ola.product_id,


            COALESCE
            (
                dc.customer_key,
                0
            ) AS customer_key,

            COALESCE
            (
                de.employee_key,
                0
            ) AS employee_key,

            COALESCE
            (
                dp.product_key,
                0
            ) AS product_key,

            COALESCE
            (
                dsh.shipper_key,
                0
            ) AS shipper_key,

            COALESCE
            (
                dd_order.MiladiDateKey,
                0
            ) AS order_date_key,

            COALESCE
            (
                dd_required.MiladiDateKey,
                0
            ) AS required_date_key,

            COALESCE
            (
                dd_shipped.MiladiDateKey,
                0
            ) AS shipped_date_key,

            ola.unit_price,
            ola.quantity,
            ola.discount_rate,

            CAST
            (
                ola.unit_price * ola.quantity
                AS DECIMAL(19,4)

            ) AS gross_amount,

            CAST
            (
                (
                    ola.unit_price * ola.quantity
                )
                *
                ola.discount_rate

                AS DECIMAL(19,4)

            ) AS discount_amount,

            CAST
            (
                (ola.unit_price * ola.quantity)
                - ((ola.unit_price * ola.quantity) * ola.discount_rate)
                AS DECIMAL(19,4)
            ) AS net_amount,


            (freight_amount / sum(ola.Quantity) over(partition by o.order_id)) * ola.quantity as freight_amount,
            @load_datetime

        FROM orders_cleaned AS o

        INNER JOIN order_line_aggregated AS ola
            ON o.order_id = ola.order_id

        LEFT JOIN sale.dim_customer AS dc
            ON dc.customer_id = o.customer_id

        LEFT JOIN sale.dim_employee AS de
            ON de.employee_id = o.employee_id

        LEFT JOIN sale.dim_product AS dp
            ON dp.product_id = ola.product_id

        LEFT JOIN sale.dim_shipper AS dsh
            ON dsh.shipper_id = o.ship_via

        LEFT JOIN dds.dbo.dim_date AS dd_order
            ON dd_order.MiladiDate = o.order_date

        LEFT JOIN dds.dbo.dim_date AS dd_required
            ON dd_required.MiladiDate = o.required_date

        LEFT JOIN dds.dbo.dim_date AS dd_shipped
            ON dd_shipped.MiladiDate = o.shipped_date


        WHERE ola.quantity > 0
          AND ola.unit_price >= 0;

        COMMIT TRANSACTION;

        PRINT
            'Full Load completed successfully for sale.fact_order.';

    END TRY

    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
GO

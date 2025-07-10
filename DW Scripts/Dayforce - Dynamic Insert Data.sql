ALTER PROC [dayforce_s].[Dynamic_Truncate_and_Insert] AS
BEGIN
	-- Declare variables
	DECLARE @TargetTable NVARCHAR(4000);
	DECLARE @SourceTable NVARCHAR(4000);
	DECLARE @SQL NVARCHAR(MAX);
	DECLARE @RowID INT;
	DECLARE @MaxRowID INT;
	DECLARE @ColumnList NVARCHAR(MAX);
	DECLARE @ColumnSQL NVARCHAR(MAX);
	DECLARE @TableSchema NVARCHAR(128) = 'dayforce_s';

	-- Initialize the RowID
	SET @RowID = 1;

	-- Get the total number of rows in Parameter_Table_Dayforce
	SELECT @MaxRowID = COUNT(*)
	FROM dayforce_s.Parameter_Table_Dayforce;

	-- Loop through each row in Parameter_Table_Dayforce
	WHILE @RowID <= @MaxRowID
	BEGIN
		-- Get the target table name for the current row
		SELECT @TargetTable = Destination_Table_Name
		FROM dayforce_s.Parameter_Table_Dayforce
		WHERE id = @RowID;

		-- Set the source table name
		SET @SourceTable = 'Stage_' + @TargetTable;

		-- Check if the table is MSUK_DW_Employee_Pay_Summary
		IF @TargetTable = 'Employee_Pay_Summary'
			OR @RowID = 19
		BEGIN
			-- removed the last 100 days of data
			DELETE
			FROM dayforce_s.Employee_Pay_Summary
			WHERE Employee_Pay_Summary_Pay_Date >= DATEADD(DAY, - 100, Cast(GETDATE() AS DATE))

			-- Insert new data from the source table
			INSERT INTO dayforce_s.Employee_Pay_Summary
			SELECT [s].[Employee_ID],
				[s].[Employee_Pay_Adjust_ID],
				[s].[Employee_Pay_Summary_Is_Duplicate_Time],
				cast([s].[Employee_Pay_Summary_Pay_Date] AS DATETIME2) AS [Employee_Pay_Summary_Pay_Date],
				cast([s].[Employee_Pay_Summary_Time_Start] AS DATETIME2) AS [Employee_Pay_Summary_Time_Start],
				cast([s].[Employee_Pay_Summary_Time_End] AS DATETIME2) AS [Employee_Pay_Summary_Time_End],
				[s].[Employee_Pay_Summary_Net_Hours],
				[s].[Minute_Duration],
				[s].[Employee_Pay_Summary_Rate],
				[s].[Pay_Amount],
				[s].[Is_Premium],
				[s].[Department_ID],
				[s].[Job_Assignment_ID],
				[s].[Job_ID],
				[s].[Location_ID],
				[s].[Pay_Category_ID],
				[s].[Pay_Code_ID],
				[s].[Schedule_ID],
				[s].[Time_Entry_ID]
			FROM dayforce_s.Stage_Employee_Pay_Summary s
				--SET @RowID = @RowID + 1
		END
				-- If not MSUK_DW_Employee_Pay_Summary, proceed with truncate and insert
		ELSE
		BEGIN
			-- Generate the column list with necessary type conversions
			SELECT @ColumnList = STRING_AGG(CASE 
						WHEN DATA_TYPE IN ('date', 'datetime', 'datetime2', 'datetimeoffset', 'smalldatetime')
							THEN 'CAST(' + QUOTENAME(COLUMN_NAME) + ' AS ' + DATA_TYPE + ') AS ' + QUOTENAME(COLUMN_NAME)
						ELSE QUOTENAME(COLUMN_NAME)
						END, ', ')
			FROM INFORMATION_SCHEMA.COLUMNS
			WHERE TABLE_NAME = @TargetTable
				AND TABLE_SCHEMA = @TableSchema;

			-- Construct dynamic SQL to truncate the target table
			SET @SQL = 'TRUNCATE TABLE [' + @TableSchema + '].' + QUOTENAME(@TargetTable) + ';';
			-- Append the dynamic SQL to insert records from the corresponding source table with date conversion
			SET @SQL = @SQL + '
            INSERT INTO ' + QUOTENAME(@TableSchema) + '.' + QUOTENAME(@TargetTable) + ' SELECT ' + @ColumnList + ' FROM ' + QUOTENAME(@TableSchema) + '.' + QUOTENAME(@SourceTable) + ';';

			/*SET @SQL = @SQL + '
            INSERT INTO [' + @TableSchema + '].' + QUOTENAME(@TargetTable) + ' (' + @ColumnList + ')
            SELECT ' + @ColumnList + '
            FROM [' + @TableSchema + '].' + QUOTENAME(@SourceTable) + ';';*/
			-- Execute the dynamic SQL
			EXEC sp_executesql @SQL;
		END

		-- Move to the next row
		SET @RowID = @RowID + 1;
	END
END;
	/*
If ID =  19 and table name = MSUK_DW_Employee_Pay_Summary then skip the truncate and insert, need to do a delete of current month data and insert new month data

*/
	-- Original code for truncating and inserting data into tables based on the Parameter_Table_Dayforce.
	/*


ALTER PROC [dayforce_s].[Dynamic_Truncate_and_Insert] AS
BEGIN
	-- Declare variables
	DECLARE @TargetTable NVARCHAR(4000);
	DECLARE @SourceTable NVARCHAR(4000);
	DECLARE @SQL NVARCHAR(MAX);
	DECLARE @RowID INT;
	DECLARE @MaxRowID INT;
	DECLARE @ColumnList NVARCHAR(MAX);
	DECLARE @ColumnSQL NVARCHAR(MAX);
	DECLARE @TableSchema NVARCHAR(128) = 'dayforce_s';

	-- Initialize the RowID
	SET @RowID = 1;

	-- Get the total number of rows in Parameter_Table_Dayforce
	SELECT @MaxRowID = COUNT(*)
	FROM dayforce_s.Parameter_Table_Dayforce;

	-- Loop through each row in Parameter_Table_Dayforce
	WHILE @RowID <= @MaxRowID
	BEGIN
		-- Get the target table name for the current row
		SELECT @TargetTable = Destination_Table_Name
		FROM dayforce_s.Parameter_Table_Dayforce
		WHERE id = @RowID;

		-- Set the source table name
		SET @SourceTable = 'Stage_' + @TargetTable;

		-- Generate the column list with necessary type conversions
		SELECT @ColumnList = STRING_AGG(CASE 
					WHEN DATA_TYPE IN ('date', 'datetime', 'datetime2', 'datetimeoffset', 'smalldatetime')
						THEN 'CAST(' + QUOTENAME(COLUMN_NAME) + ' AS ' + DATA_TYPE + ') AS ' + QUOTENAME(COLUMN_NAME)
					ELSE QUOTENAME(COLUMN_NAME)
					END, ', ')
		FROM INFORMATION_SCHEMA.COLUMNS
		WHERE TABLE_NAME = @TargetTable
			AND TABLE_SCHEMA = @TableSchema;

		-- Construct dynamic SQL to truncate the target table
		SET @SQL = 'TRUNCATE TABLE [' + @TableSchema + '].' + QUOTENAME(@TargetTable) + ';';
		-- Append the dynamic SQL to insert records from the corresponding source table with date conversion
		SET @SQL = @SQL + '
            INSERT INTO ' + QUOTENAME(@TableSchema) + '.' + QUOTENAME(@TargetTable) + ' SELECT ' + @ColumnList + ' FROM ' + QUOTENAME(@TableSchema) +'.' + QUOTENAME(@SourceTable) + ';';

		/*SET @SQL = @SQL + '
            INSERT INTO [' + @TableSchema + '].' + QUOTENAME(@TargetTable) + ' (' + @ColumnList + ')
            SELECT ' + @ColumnList + '
            FROM [' + @TableSchema + '].' + QUOTENAME(@SourceTable) + ';';*/
		-- Execute the dynamic SQL
		EXEC sp_executesql @SQL;

		-- Move to the next row
		SET @RowID = @RowID + 1;
	END;
END;
GO



*/

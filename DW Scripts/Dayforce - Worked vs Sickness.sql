WITH tafw
AS (
	SELECT [tafw].[TAFW_ID],
		[tafw].[Employee_TAFW_Date_Time_Start],
		dateadd(DAY, - 1, [tafw].[Employee_TAFW_Date_Time_End]) AS Employee_TAFW_Date_Time_End,
		[tafw].[Employee_TAFW_Days],
		[tafw].[Employee_TAFW_Net_Hours],
		[tafw].[TAFW_Status_Name],
		[tafw].[Pay_Category_Description],
		[tafw].[Pay_Code_Name],
		[tafw].[Pay_Code_Description],
		[tafw].[Employee_ID]
	FROM dayforce_s.Employee_TAFW tafw
	WHERE tafw.TAFW_Status_Name = 'Approved'
	)
SELECT DISTINCT [s].[Employee_Pay_Summary_Is_Duplicate_Time],
	[s].[Employee_Pay_Summary_Pay_Date],
	sum([s].[Employee_Pay_Summary_Net_Hours]) AS Employee_Pay_Summary_Net_Hours,
	--sum([s].[Minute_Duration]) AS Minute_Duration,
	Sum([s].[Employee_Pay_Summary_Rate]) AS Employee_Pay_Summary_Rate,
	sum([s].[Pay_Amount]) AS Pay_Amount,
	tafw.Pay_Code_Name
FROM dayforce_s.Employee_Pay_Summary s
LEFT JOIN dayforce_s.Employee e
	ON s.Employee_ID = e.Employee_Employee_ID
LEFT JOIN tafw
	ON s.Employee_ID = tafw.Employee_ID
		AND s.Employee_Pay_Summary_Pay_Date BETWEEN tafw.Employee_TAFW_Date_Time_Start
			AND tafw.Employee_TAFW_Date_Time_End
		AND tafw.TAFW_Status_Name = 'Approved'
WHERE e.Employee_First_Name = 'Jay'
	AND s.Employee_Pay_Summary_Pay_Date >= '2025-01-01'
	AND s.Employee_Pay_Summary_Pay_Date <= '2025-12-31'
	AND s.Employee_Pay_Summary_Rate > 0
GROUP BY [s].[Employee_Pay_Summary_Is_Duplicate_Time],
	[s].[Employee_Pay_Summary_Pay_Date],
	tafw.Pay_Code_Name
ORDER BY 4

	--459
	--463
	/*
TO DO

[] Need to find an employee with non company sick pay to see the if it is 0 in the summary.
[] Contracted hours per day to validate working date

*/

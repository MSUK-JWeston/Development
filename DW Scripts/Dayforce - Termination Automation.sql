--ALTER PROC [dayforce_s].[Establishment] @Date [DATE],@Employment_Status [NVARCHAR](4000),@User [NVARCHAR](4000) AS
/*
Establishment Report from Dayforce for Power BI Paginated Reports.

This report is to show every colleague in the organisation past and present.

This passing in the user running the report from Power BI Paginated reports to pick out column-level security.

*/
/*
--Parameters passed in to test the report.

DECLARE @Date DATE,
	@Employment_Status NVARCHAR(4000)

SET @Employment_Status = 'Active,Inactive,Terminated,Working Notice,Pre-Start'
SET @Date = cast('2024-09-20' AS DATE);

DECLARE @User [NVARCHAR] (4000) = 'jay.weston@msichoices.org.uk'


*/
DECLARE @Limited BIT = (
		SELECT 1
		FROM dayforce_s.RLS_Limited_Establishment
		WHERE ID_Library_Log_in_Name = @User
		);
DECLARE @Full BIT = (
		SELECT 1
		FROM dayforce_s.RLS_Full_Establishment
		WHERE ID_Library_Log_in_Name = @User
		);

/*
When using IN fuction on parameters on Paginated reports it did not recongise the text split
It is taking the contant from the parameter and spliting it out to satisfy the IN on the report
*/
BEGIN
	-- Create a temporary table to hold the split values
	CREATE TABLE #StatusTable (Employment_Status NVARCHAR(255));

	-- Split the @Employment_Status using STRING_SPLIT (assuming you have SQL Server 2016+ compatibility)
	WITH Split_CTE
	AS (
		SELECT value AS Employment_Status
		FROM STRING_SPLIT(@Employment_Status, ',')
		)
	INSERT INTO #StatusTable (Employment_Status)
	SELECT Employment_Status
	FROM Split_CTE
END;

WITH Location --Pulling out all unique Locations
AS (
	SELECT DISTINCT *
	FROM dayforce_s.[Location] l
	),
Employment_Status_Updated -- 3 staff members were duplicating which is true to the data due to having 2 employee numbers, HR requested to overwrite original employee number with the last employee number to only show 3 heads instead of 6.
AS (
	SELECT [es].[Employee_Employment_Status_ID],
		replace(replace(replace([es].[Employee_Number], 'M3517', 'M5980'), 'M4883', 'M5992'), 'M5274', 'M5988') Employee_Number,
		[es].[Employee_Employment_Status_Effective_Start],
		[es].[Employee_Employment_Status_Effective_End],
		[es].[Normal_Weekly_Hours],
		[es].[Employee_Group_Name],
		[es].[Employment_Status_Name],
		[es].[Pay_Type_Name],
		[es].[Pay_Class_Description],
		[es].[Pay_Class_Name],
		[es].[Base_Rate],
		[es].[Base_Salary],
		[es].[Employee_Employment_Status_Employee_ID]
	FROM dayforce_s.Employee_Employment_Status es
	),
Termination -- Get all terminated staff members 
AS (
	SELECT *
	FROM dayforce_s.Employee_Employment_Status
	WHERE Employment_Status_Name = 'Terminated'
	),
Rehire --Using ther Terminations to Calculate if a staff member is a Rehire.
AS (
	SELECT [s].[Employee_Employment_Status_ID],
		[s].[Employee_Number],
		t.Employee_Employment_Status_Effective_Start Termination_Start_Date,
		[s].[Employee_Employment_Status_Effective_Start],
		[s].[Employee_Employment_Status_Effective_End],
		[s].[Employment_Status_Name],
		s.Employee_Employment_Status_Employee_ID
	FROM dayforce_s.Employee_Employment_Status s
	LEFT OUTER JOIN Termination t
		ON s.Employee_Employment_Status_Employee_ID = t.Employee_Employment_Status_Employee_ID
			AND s.Employee_Employment_Status_ID <> t.Employee_Employment_Status_ID
			AND isnull(s.Employee_Employment_Status_Effective_End, cast(GETDATE() AS DATE)) >= t.Employee_Employment_Status_Effective_Start
	WHERE NOT s.Employment_Status_Name IN ('Terminated', 'Inactive')
		AND t.Employment_Status_Name IS NOT NULL
	),
WFH_Staff --SharePoint List data on WFH Risk Assessments
AS (
	SELECT Email WFH_Email,
		max(Form_Updated_Date) WFH_Risk_Assessment_Updated_Date
	FROM [dayforce].[WFH_Risk_Assessment]
	GROUP BY email
	),
Current_Staff -- Pulling out the current staff based on the date entered on the report.
AS (
	SELECT DISTINCT es.Employee_Group_Name [Resource_Type],
		es.Employee_Number,
		e.Employee_First_Name First_Name,
		e.Employee_Last_Name Last_Name,
		e.Original_Hire_Date,
		e.Hire_Date,
		e.Seniority_Date [Probation_Date_End_Date],
		e.Entitlement_Override_Date [FTC_End_Date],
		CASE 
			WHEN r.Employee_Number IS NOT NULL
				THEN NULL
			ELSE e.Termination_Date
			END Termination_Date, -- When a someone is a rehire, to remove the global termination date.
		CASE 
			WHEN r.Employee_Number IS NOT NULL
				THEN 'Y'
			ELSE NULL
			END AS is_Rehire,
		es.Employment_Status_Name Employment_Status,
		ja.Job_Name [Job_Assignment_Name],
		em.Employee_Display_Name [Manager_Name],
		CAST(es.Normal_Weekly_Hours AS DECIMAL(10, 2)) [Employee_Contracted_Hours],
		CAST(ja.Job_Assignment_Weekly_Hours AS DECIMAL(10, 2)) [FTE_Hours],
		NULL [FTE_Salary],
		CAST(DATEDIFF(day, e.Hire_Date, CASE 
					WHEN es.Employment_Status_Name = 'Terminated'
						AND e.Termination_Date <= @Date
						THEN e.Termination_Date
					ELSE @Date
					END) / 365.25 AS DECIMAL(10, 2)) AS [Length_of_Service],
		dbo.fn_Date_Difference_Years_Months_Days(e.Hire_Date, CASE 
				WHEN es.Employment_Status_Name = 'Terminated'
					AND e.Termination_Date <= @Date
					THEN e.Termination_Date
				ELSE @Date
				END) AS [Length_of_Service_Long],
		ja.Job_Function_Name [Job_Function],
		es.Pay_Class_Name [Pay_Class],
		es.Pay_Type_Name [Pay_Type],
		l.Location_Name,
		l.Site,
		l.Ledger_Code,
		es.[Base_Rate],
		es.[Base_Salary] [Base_Salary],
		ja.Pay_Grade_Name [Pay_Grade],
		CAST(wa.FTE_Value AS DECIMAL(10, 2)) FTE_Value,
		wa.Work_Assignment_Is_Virtual,
		e.ID_Library_Log_in_Name,
		e.Employee_Gender Gender,
		e.Ethnicity,
		e.National_ID_Number AS NI_Number,
		e.Employee_Registered_Disabled,
		pa.Person_Address_1,
		pa.Person_Address_2,
		pa.Person_Address_3,
		pa.Person_Address_4,
		pa.Person_Address_City,
		pa.Person_Address_County,
		pa.Person_Address_Postcode,
		pc.Person_Contact_Electronic_Address Personal_Email,
		[ci].[Identification_Type_Name],
		[ci].[Identification_Number],
		e.Employee_Date_of_Birth,
		e.Employee_Age,
		wfh.WFH_Risk_Assessment_Updated_Date
	FROM dayforce_s.Employee e
	LEFT OUTER JOIN dayforce_s.Employee_Manager m
		ON e.Employee_Employee_ID = m.Employee_ID
	LEFT OUTER JOIN dayforce_s.Employee em
		ON em.Employee_Employee_ID = m.Manager_ID
	LEFT OUTER JOIN Employment_Status_Updated es
		ON es.Employee_Employment_Status_Employee_ID = e.Employee_Employee_ID
	LEFT OUTER JOIN dayforce_s.Employee_Work_Assignment wa
		ON wa.Employee_Work_Assignment_Employee_Id = e.Employee_Employee_Id
			AND wa.Primary_Work_Assignment = 'True'
	LEFT OUTER JOIN dayforce_s.Job_Assignment ja
		ON ja.Job_Assignment_ID = wa.Employee_Work_Assignment_Job_Assignment_Id
	LEFT OUTER JOIN Location l
		ON l.Location_Id = wa.Location_Id
	LEFT OUTER JOIN dayforce_s.Person_Address pa
		ON pa.Person_ID = e.Employee_Employee_ID
			AND @Date BETWEEN pa.Person_Address_Effective_Start AND ISNULL(pa.Person_Address_Effective_End, @Date)
	LEFT OUTER JOIN dayforce_s.Person_Contact pc
		ON pc.Person_ID = e.Employee_Employee_ID
			AND @Date BETWEEN pc.Person_Contact_Effective_Start AND ISNULL(pc.Person_Contact_Effective_End, @Date)
			AND pc.Person_Contact_Is_For_System_Communications = 'false'
			AND pc.Person_Contact_Electronic_Address IS NOT NULL
			AND NOT pc.Person_Contact_Electronic_Address LIKE '%@msichoices.org.uk%'
	LEFT OUTER JOIN dayforce_s.Employee_Confidential_Identification ci
		ON ci.Employee_ID = e.Employee_Employee_ID
			AND @Date BETWEEN ci.Identification_Effective_From AND ISNULL(ci.Identification_Effective_To, @Date)
			AND NOT ci.Identification_Number LIKE '%AGRESSO%'
	LEFT OUTER JOIN Rehire r
		ON r.Employee_Employment_Status_ID = es.Employee_Employment_Status_ID
	LEFT OUTER JOIN WFH_Staff wfh
		ON wfh.WFH_Email = e.ID_Library_Log_in_Name
	WHERE (
			NOT es.Employee_Group_Name LIKE '%International%'
			OR es.Employee_Group_Name IS NULL
			)
		AND @Date BETWEEN m.Manager_Effective_Start AND ISNULL(m.Manager_Effective_End, @Date)
		AND @Date BETWEEN es.Employee_Employment_Status_Effective_Start AND ISNULL(es.Employee_Employment_Status_Effective_End, @Date)
		AND @Date BETWEEN wa.Work_Assignment_Effective_Start AND ISNULL(wa.Work_Assignment_Effective_End, @Date)
	),
All_Other_Staff -- Getting all terminated staff and pre-active staff.
AS (
	SELECT [t].[Resource_Type],
		[t].[Employee_Number],
		[t].[First_Name],
		[t].[Last_Name],
		[t].[Original_Hire_Date],
		[t].[Hire_Date],
		[t].[Probation_Date_End_Date],
		[t].[FTC_End_Date],
		[t].[Termination_Date],
		[t].[is_Rehire],
		[t].[Employment_Status],
		[t].[Job_Assignment_Name],
		[t].[Manager_Name],
		[t].[Employee_Contracted_Hours],
		[t].[FTE_Hours],
		[t].[FTE_Salary],
		[t].[Length_of_Service],
		[t].[Length_of_Service_Long],
		[t].[Job_Function],
		[t].[Pay_Class],
		[t].[Pay_Type],
		[t].[Location_Name],
		[t].[Site],
		[t].[Ledger_Code],
		[t].[Base_Rate],
		[t].[Base_Salary],
		[t].[Pay_Grade],
		[t].[FTE_Value],
		[t].[Work_Assignment_Is_Virtual],
		[t].[ID_Library_Log_in_Name],
		[t].[Gender],
		[t].[Ethnicity],
		[t].[NI_Number],
		[t].[Employee_Registered_Disabled],
		[t].[Person_Address_1],
		[t].[Person_Address_2],
		[t].[Person_Address_3],
		[t].[Person_Address_4],
		[t].[Person_Address_City],
		[t].[Person_Address_County],
		[t].[Person_Address_Postcode],
		[t].[Personal_Email],
		[t].[Identification_Type_Name],
		[t].[Identification_Number],
		[t].[Employee_Date_of_Birth],
		[t].[Employee_Age],
		[t].[WFH_Risk_Assessment_Updated_Date]
	FROM (
		SELECT DISTINCT es.Employee_Group_Name [Resource_Type],
			es.Employee_Number,
			e.Employee_First_Name First_Name,
			e.Employee_Last_Name Last_Name,
			e.Original_Hire_Date,
			e.Hire_Date,
			e.Seniority_Date [Probation_Date_End_Date],
			e.Entitlement_Override_Date [FTC_End_Date],
			CASE 
				WHEN r.Employee_Number IS NOT NULL
					THEN NULL
				ELSE e.Termination_Date
				END Termination_Date,
			CASE 
				WHEN r.Employee_Number IS NOT NULL
					THEN 'Y'
				ELSE NULL
				END AS is_Rehire,
			es.Employment_Status_Name Employment_Status,
			ja.Job_Name [Job_Assignment_Name],
			em.Employee_Display_Name [Manager_Name],
			CAST(es.Normal_Weekly_Hours AS DECIMAL(10, 3)) [Employee_Contracted_Hours],
			CAST(ja.Job_Assignment_Weekly_Hours AS DECIMAL(10, 3)) [FTE_Hours],
			NULL [FTE_Salary],
			CAST(DATEDIFF(day, e.Hire_Date, CASE 
						WHEN es.Employment_Status_Name = 'Terminated'
							AND e.Termination_Date <= @Date
							THEN e.Termination_Date
						ELSE @Date
						END) / 365.25 AS DECIMAL(10, 3)) AS [Length_of_Service],
			dbo.fn_Date_Difference_Years_Months_Days(e.Hire_Date, CASE 
					WHEN es.Employment_Status_Name = 'Terminated'
						AND e.Termination_Date <= @Date
						THEN e.Termination_Date
					ELSE @Date
					END) AS [Length_of_Service_Long],
			ja.Job_Function_Name [Job_Function],
			es.Pay_Class_Name [Pay_Class],
			es.Pay_Type_Name [Pay_Type],
			l.Location_Name,
			l.Site,
			l.Ledger_Code,
			es.[Base_Rate],
			es.[Base_Salary],
			ja.Pay_Grade_Name [Pay_Grade],
			CAST(wa.FTE_Value AS DECIMAL(10, 2)) FTE_Value,
			wa.Work_Assignment_Is_Virtual,
			ROW_NUMBER() OVER (
				PARTITION BY es.Employee_Number ORDER BY ISNULL(es.Employee_Employment_Status_Effective_end, GETDATE()) DESC,
					ISNULL(wa.Work_Assignment_Effective_End, GETDATE()) DESC,
					ISNULL(m.Manager_Effective_End, GETDATE()) DESC
				) rwn --Getting the last record possible for the staff
			,
			e.ID_Library_Log_in_Name,
			e.Employee_Gender Gender,
			e.Ethnicity,
			e.National_ID_Number AS NI_Number,
			e.Employee_Registered_Disabled,
			pa.Person_Address_1,
			pa.Person_Address_2,
			pa.Person_Address_3,
			pa.Person_Address_4,
			pa.Person_Address_City,
			pa.Person_Address_County,
			pa.Person_Address_Postcode,
			pc.Person_Contact_Electronic_Address Personal_Email,
			[ci].[Identification_Type_Name],
			[ci].[Identification_Number],
			e.Employee_Date_of_Birth,
			e.Employee_Age,
			wfh.WFH_Risk_Assessment_Updated_Date
		FROM dayforce_s.Employee e
		LEFT OUTER JOIN dayforce_s.Employee_Manager m
			ON e.Employee_Employee_ID = m.Employee_ID
		LEFT OUTER JOIN dayforce_s.Employee em
			ON em.Employee_Employee_ID = m.Manager_ID
		LEFT OUTER JOIN Employment_Status_Updated es
			ON es.Employee_Employment_Status_Employee_ID = e.Employee_Employee_ID
		LEFT OUTER JOIN dayforce_s.Employee_Work_Assignment wa
			ON wa.Employee_Work_Assignment_Employee_Id = e.Employee_Employee_Id
				AND wa.Primary_Work_Assignment = 'True'
		LEFT OUTER JOIN dayforce_s.Job_Assignment ja
			ON ja.Job_Assignment_ID = wa.Employee_Work_Assignment_Job_Assignment_Id
		LEFT OUTER JOIN Location l
			ON l.Location_Id = wa.Location_Id
		LEFT OUTER JOIN dayforce_s.Person_Address pa
			ON pa.Person_ID = e.Employee_Employee_ID
				AND @Date BETWEEN pa.Person_Address_Effective_Start AND ISNULL(pa.Person_Address_Effective_End, @Date)
		LEFT OUTER JOIN dayforce_s.Person_Contact pc
			ON pc.Person_ID = e.Employee_Employee_ID
				AND @Date BETWEEN pc.Person_Contact_Effective_Start AND ISNULL(pc.Person_Contact_Effective_End, @Date)
				AND pc.Person_Contact_Is_For_System_Communications = 'false'
				AND pc.Person_Contact_Electronic_Address IS NOT NULL
				AND NOT pc.Person_Contact_Electronic_Address LIKE '%@msichoices.org.uk%'
		LEFT OUTER JOIN dayforce_s.Employee_Confidential_Identification ci
			ON ci.Employee_ID = e.Employee_Employee_ID
				AND @Date BETWEEN ci.Identification_Effective_From AND ISNULL(ci.Identification_Effective_To, @Date)
				AND NOT ci.Identification_Number LIKE '%AGRESSO%'
		LEFT OUTER JOIN Rehire r
			ON r.Employee_Employment_Status_ID = es.Employee_Employment_Status_ID
		LEFT OUTER JOIN WFH_Staff wfh
			ON wfh.WFH_Email = e.ID_Library_Log_in_Name
		WHERE (
				NOT es.Employee_Group_Name LIKE '%International%'
				OR es.Employee_Group_Name IS NULL
				)
		) t
	WHERE rwn = 1
		AND NOT Employee_Number IN (
			SELECT Employee_Number
			FROM Current_Staff
			)
	),
Restriced
AS (
	SELECT [s].[Resource_Type],
		[s].[Employee_Number],
		[s].[First_Name],
		[s].[Last_Name],
		[s].[Original_Hire_Date],
		[s].[Hire_Date],
		[s].[Probation_Date_End_Date],
		[s].[FTC_End_Date],
		[s].[Termination_Date],
		[s].[is_Rehire],
		[s].[Employment_Status],
		[s].[Job_Assignment_Name],
		[s].[Manager_Name],
		[s].[Employee_Contracted_Hours],
		[s].[FTE_Hours],
		CASE 
			WHEN @Limited = 1
				AND NOT s.Location_Name IN ('Human Resources P and D') --Originally required for HR team members can see salary information of all staff except HR. This has changes to HR team members not to see any Salary information. This has been fixed in the view. I have left in to show as an example of how to do this if it is needed in the future.
				THEN (s.FTE_Hours * s.Base_Rate) * 52
			WHEN @Full = 1
				THEN (s.FTE_Hours * s.Base_Rate) * 52
			ELSE NULL -- Anyone in not in the RLS will return no values
			END [FTE_Salary],
		[s].[Length_of_Service],
		[s].[Length_of_Service_Long],
		[s].[Job_Function],
		[s].[Pay_Class],
		[s].[Pay_Type],
		[s].[Location_Name],
		[s].[Site],
		[s].[Ledger_Code],
		CASE 
			WHEN @Limited = 1
				AND NOT s.Location_Name IN ('Human Resources P and D')
				THEN [s].[Base_Rate]
			WHEN @Full = 1
				THEN [s].[Base_Rate]
			ELSE NULL
			END [Hourly_Rate],
		CASE 
			WHEN @Limited = 1
				AND NOT s.Location_Name IN ('Human Resources P and D')
				THEN [s].[Base_Salary]
			WHEN @Full = 1
				THEN [s].[Base_Salary]
			ELSE NULL
			END Current_Salary,
		CASE 
			WHEN @Limited = 1
				AND NOT s.Location_Name IN ('Human Resources P and D')
				THEN [s].[Pay_Grade]
			WHEN @Full = 1
				THEN [s].[Pay_Grade]
			ELSE NULL
			END [Pay_Grade],
		[s].[FTE_Value],
		[s].[Work_Assignment_Is_Virtual],
		s.ID_Library_Log_in_Name AS MSI_Email,
		[s].[Gender],
		[s].[Ethnicity],
		[s].[NI_Number],
		[s].[Employee_Registered_Disabled],
		[s].[Person_Address_1],
		[s].[Person_Address_2],
		[s].[Person_Address_3],
		[s].[Person_Address_4],
		[s].[Person_Address_City],
		[s].[Person_Address_County],
		[s].[Person_Address_Postcode],
		[s].[Personal_Email],
		[s].[Identification_Type_Name],
		[s].[Identification_Number],
		[s].[Employee_Date_of_Birth],
		[s].[Employee_Age],
		[s].[WFH_Risk_Assessment_Updated_Date],
		ROW_NUMBER() OVER (
			PARTITION BY [s].[Employee_Number] ORDER BY [s].[Employee_Number]
			) rwnc
	FROM (
		SELECT *
		FROM Current_Staff
		
		UNION ALL
		
		SELECT *
		FROM All_Other_Staff
		) s
	WHERE s.Employment_Status IN (
			SELECT Employment_Status
			FROM #StatusTable
			)
		AND (
			NOT s.ID_Library_Log_in_Name = 'marie.ford@msichoices.org.uk' -- Duplicate work email on the system due to marital name, I have notified Dayforce team to remove.
			OR s.ID_Library_Log_in_Name IS NULL
			)
	)
SELECT [r].[Resource_Type],
	[r].[Employee_Number],
	[r].[First_Name],
	[r].[Last_Name],
	[r].[Original_Hire_Date],
	[r].[Hire_Date],
	[r].[Probation_Date_End_Date],
	[r].[FTC_End_Date],
	[r].[Termination_Date],
	[r].[is_Rehire],
	[r].[Employment_Status],
	[r].[Job_Assignment_Name],
	[r].[Manager_Name],
	[r].[Employee_Contracted_Hours],
	[r].[FTE_Hours],
	[r].[FTE_Salary],
	[r].[Length_of_Service],
	[r].[Length_of_Service_Long],
	[r].[Job_Function],
	[r].[Pay_Class],
	[r].[Pay_Type],
	[r].[Location_Name],
	[r].[Site],
	[r].[Ledger_Code],
	[r].[Hourly_Rate],
	[r].[Current_Salary],
	[r].[Pay_Grade],
	[r].[FTE_Value],
	[r].[Work_Assignment_Is_Virtual],
	[r].[MSI_Email],
	[r].[Gender],
	[r].[Ethnicity],
	[r].[NI_Number],
	STRING_AGG(Identification_Type_Name + ': ' + Identification_Number, '; ') RTW_ID, -- Grouping multiple idetification types to resolve to be a single row for each colleague
	[r].[Employee_Registered_Disabled],
	[r].[Person_Address_1],
	[r].[Person_Address_2],
	[r].[Person_Address_3],
	[r].[Person_Address_4],
	[r].[Person_Address_City],
	[r].[Person_Address_County],
	[r].[Person_Address_Postcode],
	[r].[Personal_Email],
	[r].[Employee_Date_of_Birth],
	[r].[Employee_Age],
	[r].[WFH_Risk_Assessment_Updated_Date]
FROM Restriced r
GROUP BY [r].[Resource_Type],
	[r].[Employee_Number],
	[r].[First_Name],
	[r].[Last_Name],
	[r].[Original_Hire_Date],
	[r].[Hire_Date],
	[r].[Probation_Date_End_Date],
	[r].[FTC_End_Date],
	[r].[Termination_Date],
	[r].[is_Rehire],
	[r].[Employment_Status],
	[r].[Job_Assignment_Name],
	[r].[Manager_Name],
	[r].[Employee_Contracted_Hours],
	[r].[FTE_Hours],
	[r].[FTE_Salary],
	[r].[Length_of_Service],
	[r].[Length_of_Service_Long],
	[r].[Job_Function],
	[r].[Pay_Class],
	[r].[Pay_Type],
	[r].[Location_Name],
	[r].[Site],
	[r].[Ledger_Code],
	[r].[Hourly_Rate],
	[r].[Current_Salary],
	[r].[Pay_Grade],
	[r].[FTE_Value],
	[r].[Work_Assignment_Is_Virtual],
	[r].[MSI_Email],
	[r].[Gender],
	[r].[Ethnicity],
	[r].[NI_Number],
	[r].[Employee_Registered_Disabled],
	[r].[Person_Address_1],
	[r].[Person_Address_2],
	[r].[Person_Address_3],
	[r].[Person_Address_4],
	[r].[Person_Address_City],
	[r].[Person_Address_County],
	[r].[Person_Address_Postcode],
	[r].[Personal_Email],
	[r].[Employee_Date_of_Birth],
	[r].[Employee_Age],
	[r].[WFH_Risk_Assessment_Updated_Date]

-- Drop the temporary table
DROP TABLE #StatusTable;
GO

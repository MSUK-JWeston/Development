ALTER PROC dayforce_s.sp_Termination_Automation
AS
DECLARE @Date DATE = cast(getdate() AS DATE);-- Set the date for the report

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
		[es].[Employee_Employment_Status_Employee_ID],
		Status_Reason_Name
	FROM dayforce_s.Employee_Employment_Status es
	WHERE Employment_Status_Name = 'Terminated'
		AND Employee_Employment_Status_Effective_End IS NULL
		AND @Date <= es.Employee_Employment_Status_Effective_Start
	),
Current_Staff -- Pulling out the current staff based on the date entered on the report.
AS (
	SELECT DISTINCT es.Employee_Group_Name [Resource_Type],
		es.Employee_Number,
		e.Employee_First_Name First_Name,
		e.Employee_Last_Name Last_Name,
		e.Employee_Display_Name,
		e.Original_Hire_Date,
		e.Hire_Date,
		e.Seniority_Date [Probation_Date_End_Date],
		e.Entitlement_Override_Date [FTC_End_Date],
		es.Employee_Employment_Status_Effective_Start Termination_Date,
		es.Status_Reason_Name [Termination_Reason],
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
		l.Location_Name,
		l.Site,
		l.Ledger_Code,
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
		e.Employee_Employee_ID AS Employee_ID
	FROM dayforce_s.Employee e
	LEFT JOIN dayforce_s.Employee_Manager m
		ON e.Employee_Employee_ID = m.Employee_ID
	LEFT JOIN dayforce_s.Employee em
		ON em.Employee_Employee_ID = m.Manager_ID
	INNER JOIN Employment_Status_Updated es
		ON es.Employee_Employment_Status_Employee_ID = e.Employee_Employee_ID
	LEFT JOIN dayforce_s.Employee_Work_Assignment wa
		ON wa.Employee_Work_Assignment_Employee_Id = e.Employee_Employee_Id
			AND wa.Primary_Work_Assignment = 'True'
	LEFT JOIN dayforce_s.Job_Assignment ja
		ON ja.Job_Assignment_ID = wa.Employee_Work_Assignment_Job_Assignment_Id
	LEFT JOIN Location l
		ON l.Location_Id = wa.Location_Id
	LEFT JOIN dayforce_s.Person_Address pa
		ON pa.Person_ID = e.Employee_Employee_ID
			AND @Date BETWEEN pa.Person_Address_Effective_Start
				AND ISNULL(pa.Person_Address_Effective_End, @Date)
	LEFT JOIN dayforce_s.Person_Contact pc
		ON pc.Person_ID = e.Employee_Employee_ID
			AND @Date BETWEEN pc.Person_Contact_Effective_Start
				AND ISNULL(pc.Person_Contact_Effective_End, @Date)
			AND pc.Person_Contact_Is_For_System_Communications = 'false'
			AND pc.Person_Contact_Electronic_Address IS NOT NULL
			AND NOT pc.Person_Contact_Electronic_Address LIKE '%@msichoices.org.uk%'
	LEFT JOIN dayforce_s.Employee_Confidential_Identification ci
		ON ci.Employee_ID = e.Employee_Employee_ID
			AND @Date BETWEEN ci.Identification_Effective_From
				AND ISNULL(ci.Identification_Effective_To, @Date)
			AND NOT ci.Identification_Number LIKE '%AGRESSO%'
	LEFT JOIN dayforce_s.Termination_Automation ta
		ON ta.Employee_ID = e.Employee_Employee_ID
	WHERE (
			NOT es.Employee_Group_Name LIKE '%International%'
			OR es.Employee_Group_Name IS NULL
			)
		AND @Date BETWEEN m.Manager_Effective_Start
			AND ISNULL(m.Manager_Effective_End, @Date)
		AND @Date BETWEEN wa.Work_Assignment_Effective_Start
			AND ISNULL(wa.Work_Assignment_Effective_End, @Date)
		AND ta.Employee_ID IS NULL
	)
SELECT Employee_ID,
	First_Name,
	Last_Name,
	Employee_Display_Name,
	Job_Assignment_Name AS Description,
	site AS Office,
	ID_Library_Log_in_Name AS E_mail,
	Job_Assignment_Name AS Job_Title,
	Location_Name AS Department,
	replace(Resource_Type, ' Colleague', '') AS Company,
	Manager_Name AS Manager,
	cast(Termination_Date AS DATE) AS Leaver_Date,
	'Leaving Permanently' AS Leaving_Permanently_or_Moving_to_Sessional,
	cast(GETDATE() AS DATETIME2) AS Created_Date
INTO #Termination_Automation
FROM Current_Staff cs
WHERE Termination_Date <= DATEADD(day, 7, @Date) -- Only show staff who have a termination date in the next 7 days

INSERT INTO dayforce_s.[Termination_Automation] -- Storing the results in the Termination_Automation table to ensure next day run does not duplicate.
SELECT *
FROM #Termination_Automation;

/* Query for the automtion to pull in the information below. */
SELECT [t].[First_Name],
	[t].[Last_Name],
	[t].[Employee_Display_Name],
	[t].[Description],
	[t].[Office],
	[t].[E_mail],
	[t].[Job_Title],
	[t].[Department],
	[t].[Company],
	[t].[Manager],
	[t].[Leaver_Date],
	[t].[Leaving_Permanently_or_Moving_to_Sessional]
FROM #Termination_Automation t

DROP TABLE #Termination_Automation;
	--TRUNCATE TABLE dayforce_s.[Termination_Automation];
	--SELECT * FROM dayforce_s.[Termination_Automation];
	/*
IT Requirements
GENERAL
First Name
Last Name
Display Name (Full Name)
Description (Job Title)
Office (Employees HR Location)
E-mail

ORGANIZATION
Job Title (Employees Job Title [matches Description Field])
Department (Employees HR department)
Company (Employees HR Company)
Manager

Other Information Required
Leaver Date
Leaving Permanently or Moving to Sessional
*/

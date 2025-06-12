DECLARE @Date DATE = cast(getdate() AS DATE) -- Set the date for the report
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
			e.Employee_Age
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
				AND @Date BETWEEN pa.Person_Address_Effective_Start
					AND ISNULL(pa.Person_Address_Effective_End, @Date)
		LEFT OUTER JOIN dayforce_s.Person_Contact pc
			ON pc.Person_ID = e.Employee_Employee_ID
				AND @Date BETWEEN pc.Person_Contact_Effective_Start
					AND ISNULL(pc.Person_Contact_Effective_End, @Date)
				AND pc.Person_Contact_Is_For_System_Communications = 'false'
				AND pc.Person_Contact_Electronic_Address IS NOT NULL
				AND NOT pc.Person_Contact_Electronic_Address LIKE '%@msichoices.org.uk%'
		LEFT OUTER JOIN dayforce_s.Employee_Confidential_Identification ci
			ON ci.Employee_ID = e.Employee_Employee_ID
				AND @Date BETWEEN ci.Identification_Effective_From
					AND ISNULL(ci.Identification_Effective_To, @Date)
				AND NOT ci.Identification_Number LIKE '%AGRESSO%'
		LEFT OUTER JOIN Rehire r
			ON r.Employee_Employment_Status_ID = es.Employee_Employment_Status_ID

		WHERE (
				NOT es.Employee_Group_Name LIKE '%International%'
				OR es.Employee_Group_Name IS NULL
				)
			AND @Date BETWEEN m.Manager_Effective_Start
				AND ISNULL(m.Manager_Effective_End, @Date)
			AND @Date BETWEEN es.Employee_Employment_Status_Effective_Start
				AND ISNULL(es.Employee_Employment_Status_Effective_End, @Date)
			AND @Date BETWEEN wa.Work_Assignment_Effective_Start
				AND ISNULL(wa.Work_Assignment_Effective_End, @Date)
		)

SELECT *
FROM Current_Staff cs




/*

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
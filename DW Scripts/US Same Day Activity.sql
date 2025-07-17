WITH US
AS (
	SELECT *
	FROM autom.PatientActivityDaily
	WHERE SourceType = 'Ultrasound'
	),
main
AS (
	SELECT [US].[PatientID],
		[US].[ReferralID],
		[US].[ActivityID],
		[US].[UniqueID],
		[US].[ActivityDate],
		[US].[Activity] US_Activity,
		c.Activity AS Same_Day_Consultation_Activity,
		t.Activity AS Same_Day_Treatment_Activity,
		na.Activity AS Same_Day_Non_Chargable_Activity,
		CASE 
			WHEN c.Activity IS NULL
				AND t.Activity IS NULL
				AND na.Activity IS NULL
				THEN 'No Activity'
			WHEN c.Activity IS NULL
				AND t.Activity IS NULL
				AND na.Activity IS NOT NULL
				THEN 'Non-Chargable Activity'
			WHEN c.Activity IS NOT NULL
				AND t.Activity IS NULL
				AND na.Activity IS NOT NULL
				THEN 'Consultation and Non-Chargable Activity'
			WHEN c.Activity IS NULL
				AND t.Activity IS NOT NULL
				AND na.Activity IS NOT NULL
				THEN 'Treatment and Non-Chargable Activity'
			WHEN c.Activity IS NOT NULL
				AND t.Activity IS NOT NULL
				AND na.Activity IS NOT NULL
				THEN 'Consultation, Treatment and Non-Chargable Activity'
			WHEN c.Activity IS NULL
				AND t.Activity IS NOT NULL
				THEN 'Treatment Only'
			WHEN c.Activity IS NOT NULL
				AND t.Activity IS NOT NULL
				THEN 'Consultation and Treatment'
			WHEN c.Activity IS NOT NULL
				AND t.Activity IS NULL
				THEN 'Consultation Only'
			WHEN t.Activity IS NOT NULL
				THEN 'Treatment'
			ELSE 'No Activity'
			END AS Scan_With_Activity,
		ROW_NUMBER() OVER (
			PARTITION BY us.uniqueID ORDER BY us.ActivityDate
			) AS RowNum,
		us.EligibilityContract,
		us.ICB_Name,
		na.AppointmentOutcome,
		na.AppointmentStatus,
		na.AppointmentOutcomeReason,
		na.Fee,
		na.SourceType
	FROM US
	LEFT JOIN autom.patientactivitydaily t
		ON t.ReferralID = US.ReferralID
			AND t.ActivityDate = US.ActivityDate
			AND t.uniqueID <> US.uniqueID
			AND t.Activity_Attendance_Flag = 'Y'
			AND t.Treatment_Flag = 'Y'
			AND t.Chargable_Activity_Flag = 'Y'
	LEFT JOIN autom.patientactivitydaily c
		ON c.ReferralID = US.ReferralID
			AND c.ActivityDate = US.ActivityDate
			AND c.uniqueID <> US.uniqueID
			AND c.Activity_Attendance_Flag = 'Y'
			AND c.Treatment_Flag = 'N'
			AND c.Chargable_Activity_Flag = 'Y'
	LEFT JOIN autom.patientactivitydaily na
		ON na.ReferralID = US.ReferralID
			AND na.ActivityDate = US.ActivityDate
			AND na.uniqueID <> US.uniqueID
			AND na.Activity_Attendance_Flag = 'Y'
			AND na.Treatment_Flag = 'N'
			AND na.Chargable_Activity_Flag = 'N'
			AND NOT na.AppointmentStatus IN ('DNP', 'Deferred')
			AND NOT na.SourceType IN ('Inpatient', 'Ultrasound')
			AND NOT na.Activity IN ('MA Treatment', 'STOP <12w (1hr prep)', 'ERPC', 'Telemedicine Collection')
	WHERE us.ActivityDate >= '2025-04-01'
		--AND us.PatientID = '2412908'
		--ORDER BY 11 DESC
	)
SELECT [m].[PatientID],
	[m].[ReferralID],
	[m].[ActivityID],
	[m].[UniqueID],
	[m].[ActivityDate],
	[m].[US_Activity],
	[m].[Scan_With_Activity],
	[m].[Same_Day_Consultation_Activity],
	[m].[Same_Day_Treatment_Activity],
	[m].[Same_Day_Non_Chargable_Activity],
	[m].[EligibilityContract],
	[m].[ICB_Name]
FROM main m
WHERE RowNum = 1

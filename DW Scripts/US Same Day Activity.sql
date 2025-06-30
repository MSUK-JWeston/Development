WITH US
AS (
	SELECT *
	FROM autom.PatientActivityDaily
	WHERE SourceType = 'Ultrasound'
	)
SELECT [US].[PatientID],
	[US].[ReferralID],
	[US].[ActivityID],
	[US].[UniqueID],
	[US].[ActivityDate],
	[US].[Activity] US_Activity,
	c.Activity AS Same_Day_Consultation_Activity,
	t.Activity AS Treatment_Activity,
	na.activity AS Non_Chargable_Activity,
	CASE 
		WHEN c.Activity IS NOT NULL
			AND t.Activity IS NOT NULL
			THEN 'Consultation and Treatment'
		WHEN c.Activity IS NOT NULL
			AND t.Activity IS NULL
			THEN 'Consultation'
		WHEN t.Activity IS NOT NULL
			THEN 'Treatment'
		ELSE 'No Activity'
		END AS Scan_With_Activity,
	ROW_NUMBER() OVER (
		PARTITION BY us.uniqueID ORDER BY us.ActivityDate
		) AS RowNum,
	us.EligibilityContract,
	us.ICB_Name,
	na.ActivityID,
	na.UniqueID,
	na.ActivityDate,
	na.AppointmentOutcome,
	na.AppointmentStatus,
	na.AppointmentOutcomeReason,
	na.Fee
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
		AND NOT na.SourceType = 'Ultrasound'
		AND NOT na.AppointmentStatus = 'DNP'
WHERE us.ActivityDate >= '2025-05-01'
--AND us.PatientID = '2402796'
ORDER BY 11 DESC

WITH Cons_Forms --Getting all Consultation Forms Status
AS (
	SELECT csf.versiondet Form_Version,
		lkp_progresst.TEXT Form_Status,
		csf.name Form_Name,
		csfi.sys_creation_user,
		csfi.sys_creation_datetime,
		csfi.referral
	FROM core_smartforminsta csfi WITH (NOLOCK)
	LEFT JOIN applookup_instance lkp_progresst WITH (NOLOCK)
		ON csfi.lkp_progressst = lkp_progresst.id
	LEFT JOIN core_smartform csf WITH (NOLOCK)
		ON csfi.smartformt = csf.id
	LEFT JOIN care_catsreferral ccr WITH (NOLOCK)
		ON csfi.referral = ccr.id
	WHERE csf.name = 'Consultation Assessment'
		AND (
			csfi.rie = 0
			OR csfi.rie IS NULL
			)
		AND csfi.sys_creation_datetime >= DATEADD(MONTH, - 6, cast(getdate() AS DATE))
		AND ccr.sys_creation_user = 'CareConnectapi'
	),
Cons -- Getting all Consultation appointments
AS (
	SELECT cpci.c_val AS Patient_ID,
		ISNULL(ca.name, cp2.proceduren) AS Activity,
		lkp_apptstatus.TEXT AS Cons_Status,
		CONVERT(DATETIME2, CONVERT(VARCHAR, sba.appointmen, 23) + ' ' + CONVERT(VARCHAR, sba.apptstartt, 8)) AS Cons_Activity_Start_Date_Time,
		sba.sys_creation_user Cons_Booked_By,
		sba.care_catsreferral_appointmen referral
	FROM schl_booking_appoin sba WITH (NOLOCK)
	LEFT JOIN core_activity ca WITH (NOLOCK)
		ON sba.activity = ca.id -- Activity/ Appointment Types
	LEFT JOIN schl_theatrebooking st WITH (NOLOCK)
		ON sba.theatreboo = st.id -- Inpatient bookings
	LEFT JOIN core_procedure cp2 WITH (NOLOCK)
		ON st.c_procedu = cp2.id -- Planned Procedure
	LEFT JOIN applookup_instance lkp_apptstatus WITH (NOLOCK)
		ON sba.lkp_apptstatus = lkp_apptstatus.id -- Appointment Status
	LEFT JOIN ref.ActivityTypes at WITH (NOLOCK)
		ON ISNULL(ca.name, cp2.proceduren) = at.Activity -- Activity Types
	LEFT JOIN Cons_Forms cf WITH (NOLOCK)
		ON sba.care_catsreferral_appointmen = cf.referral
	LEFT JOIN core_patient_c_identifi cpci WITH (NOLOCK)
		ON sba.patient = cpci.id
			AND cpci.lkp_c_ty = - 1905
	LEFT JOIN core_patient cp WITH (NOLOCK)
		ON cp.id = sba.patient
	LEFT JOIN care_catsreferral ccr WITH (NOLOCK)
		ON sba.care_catsreferral_appointmen = ccr.id
	WHERE at.ActivityGroup = 'Consultation'
		AND ISNULL(ca.name, cp2.proceduren) <> 'VAS Treatment'
		AND NOT lkp_apptstatus.TEXT IN ('Cancelled', 'DNA')
		AND sba.appointmen >= DATEADD(MONTH, - 6, cast(getdate() AS DATE))
		AND ccr.sys_creation_user = 'CareConnectapi'
	),
Booked_Treatment -- Getting all Treatment appointments in the future
AS (
	SELECT cpci.c_val AS Patient_ID,
		ISNULL(ca.name, cp2.proceduren) AS Activity,
		lkp_apptstatus.TEXT AS Treatment_Status,
		CONVERT(DATETIME2, CONVERT(VARCHAR, sba.appointmen, 23) + ' ' + CONVERT(VARCHAR, sba.apptstartt, 8)) AS Treatment_Start_Date_Time,
		cp.sys_creation_user,
		sba.care_catsreferral_appointmen referral,
		ccr.sys_creation_user AS Referral_Created_By
	FROM schl_booking_appoin sba WITH (NOLOCK)
	LEFT JOIN core_activity ca WITH (NOLOCK)
		ON sba.activity = ca.id -- Activity/ Appointment Types
	LEFT JOIN schl_theatrebooking st WITH (NOLOCK)
		ON sba.theatreboo = st.id -- Inpatient bookings
	LEFT JOIN core_procedure cp2 WITH (NOLOCK)
		ON st.c_procedu = cp2.id -- Planned Procedure
	LEFT JOIN applookup_instance lkp_apptstatus WITH (NOLOCK)
		ON sba.lkp_apptstatus = lkp_apptstatus.id -- Appointment Status
	LEFT JOIN ref.ActivityTypes at WITH (NOLOCK)
		ON ISNULL(ca.name, cp2.proceduren) = at.Activity -- Activity Types
	LEFT JOIN core_patient_c_identifi cpci WITH (NOLOCK)
		ON sba.patient = cpci.id
			AND cpci.lkp_c_ty = - 1905
	LEFT JOIN core_patient cp WITH (NOLOCK)
		ON cp.id = sba.patient
	LEFT JOIN care_catsreferral ccr WITH (NOLOCK)
		ON sba.care_catsreferral_appointmen = ccr.id
	WHERE sba.appointmen >= cast(GETDATE() AS DATE)
		AND at.ActivityGroup = 'Treatment'
		AND NOT ISNULL(ca.name, cp2.proceduren) IN ('VAS Treatment', 'VAS Re-op')
		AND lkp_apptstatus.TEXT = 'Booked'
		AND ccr.sys_creation_user = 'CareConnectapi'
	)
SELECT *
FROM Booked_Treatment
	/*
SELECT [bt].[Patient_ID],
	[bt].[referral] Referral_ID,
	/*
	[c].[Cons_Booked_By],
	[c].[Activity] Cons_Activity,
	[c].[Cons_Status],
	[c].[Cons_Activity_Start_Date_Time],*/
	[bt].[Activity] Treatment_Activity,
	[bt].[Treatment_Status],
	[bt].[Treatment_Start_Date_Time]
FROM Booked_Treatment bt
LEFT JOIN Cons c
	ON bt.referral = c.referral
ORDER BY 5
*/

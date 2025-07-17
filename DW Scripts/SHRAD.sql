ALTER VIEW [nhs].[SHRAD] AS 
WITH Appointments -- These are the LARC appointments to match back to the meds
AS (
	SELECT p.*,
		CASE 
			WHEN Activity IN ('BPAS Sameday MA Treatment', 'Extended MA Treatment', 'LARC', 'LARC Consultation', 'MA Treatment', 'STOP <12w (1hr prep)', 'STOP 12+1 to 14+6w (1.5hrs prep)', 'STOP 15 to 18+6w (3hrs prep)', 'STOP 22w to 23+6w', 'Telemedicine MA', 'ERPC')
				THEN '1'
			WHEN Activity IN ('BPAS Phone Consultation', 'BPAS Sameday F2F Consultation', 'Extended F2F Consultation', 'F2F Consultation', 'Phone Consultation', 'Second F2F consultation', 'Second Phone Consultation', 'Phone Consultation', 'Telemedicine Collection')
				THEN '2'
			ELSE '3'
			END AS Priority_Match
	FROM autom.PatientActivityDaily p
	LEFT OUTER JOIN pbi.[Location] l
		ON p.Hospital = l.Hospital
	WHERE p.ActivityDate >= '2024-04-01'
		AND p.ActivityDate <= '2025-03-31'
		AND AppointmentStatus IN ('Seen', 'Awaiting Result', 'Supplied', 'Discharged', 'Arrived', 'Administered', 'Admitted', 'Result Received')
		AND NOT l.[Status] = 'Non-MSI'
		AND NOT p.SourceType IN ('Medication', 'Pathology', 'HIV & Syphilis')
		AND NOT Activity IN ('Pre Assessment')

		
	),
Meds -- Get all the Medication prescribed
AS (
	SELECT p.*,
		[a].[LARCType]
	FROM autom.PatientActivityDaily p
	LEFT OUTER JOIN pbi.[Location] l
		ON p.Hospital = l.Hospital
	LEFT OUTER JOIN [ref].[ActivityTypes] a
		ON a.Activity = p.Activity
	WHERE p.ActivityDate >= '2024-04-01'
		AND p.ActivityDate <= '2025-03-31'
		AND AppointmentStatus IN ('Seen', 'Awaiting Result', 'Supplied', 'Discharged', 'Arrived', 'Administered', 'Admitted', 'Result Received')
		AND NOT l.[Status] = 'Non-MSI'
		AND p.SourceType = 'Medication'
	),
Contra_Method -- Calculating all the insertions, removals with medication
AS (
	SELECT coalesce(insertion.UniqueID, removal.UniqueID, Activity.UniqueID) LARC_UniqueID,
		Insertion.Activity Insertion_Activity,
		Activity.Activity Blank_Activity,
		Removal.Activity Removal_Activity,
		CASE 
			WHEN Insertion.ProcedurePerformed = 'Implant Insertion'
				THEN 'Implant'
			WHEN Insertion.ProcedurePerformed = 'IUD/IUS insertion'
				THEN 'IUD'
			ELSE NULL
			END Insertion_LARC,
		CASE 
			WHEN Insertion.ProcedurePerformed = 'IUD/IUS insertion'
				THEN 'IUS'
			ELSE NULL
			END Insertion_LARC2,
		CASE 
			WHEN Removal.ProcedurePerformed = 'Implant Removal'
				THEN 'Implant'
			WHEN Removal.ProcedurePerformed = 'IUD/IUS Removal'
				THEN 'IUD'
			ELSE NULL
			END Removal_LARC,
		CASE 
			WHEN Removal.ProcedurePerformed = 'IUD/IUS Removal'
				THEN 'IUS'
			ELSE NULL
			END Removal_LARC2,
		[m].[LARCType],
		[m].[PatientID],
		[m].[ReferralID],
		[m].[ActivityID],
		[m].[UniqueID],
		[m].[ReferralDate],
		[m].[BookedDate],
		[m].[ActivityDate],
		[m].[Activity],
		[m].[ServiceName],
		[m].[AppointmentStatus],
		[m].[AppointmentOutcome],
		[m].[AppointmentOutcomeReason],
		[m].[ProcedurePerformed],
		[m].[Fee],
		[m].[MFF],
		[m].[Total_Fee_Including_MFF],
		[m].[PricingActivity],
		ROW_NUMBER() OVER (
			PARTITION BY m.UniqueID ORDER BY Activity.Priority_Match,
				Insertion.ActivityID
			) rwn
	FROM Meds m
	LEFT OUTER JOIN Appointments Insertion
		ON m.PatientID = Insertion.PatientID --Using patientId instead of referral Id due to LARC precribed on different referrl ID even though it is the same date activity ¬_¬
			AND m.ActivityDate = Insertion.ActivityDate
			AND Insertion.ProcedurePerformed LIKE '%Insert%'
	LEFT OUTER JOIN Appointments Removal
		ON m.PatientID = Removal.PatientID
			AND m.ActivityDate = Removal.ActivityDate
			AND Removal.ProcedurePerformed LIKE '%Removal%'
	LEFT OUTER JOIN Appointments Activity
		ON m.PatientID = Activity.PatientID
			AND m.ActivityDate = Activity.ActivityDate
			AND (
				NOT Activity.ProcedurePerformed LIKE '%Removal%'
				OR Activity.ProcedurePerformed IS NULL
				)
			AND (
				NOT Activity.ProcedurePerformed LIKE '%Insert%'
				OR Activity.ProcedurePerformed IS NULL
				)
	),
Previous_Larc --Working out the previously used LARC
AS (
	SELECT [c].[LARC_UniqueID],
		[c].[Blank_Activity],
		[c].[Insertion_Activity],
		[c].[Removal_Activity],
		[c].[Insertion_LARC],
		[c].[Insertion_LARC2],
		[c].[Removal_LARC],
		[c].[Removal_LARC2],
		[c].[LARCType] Current_Larc,
		CASE 
			WHEN [c].[Removal_LARC] IS NOT NULL
				AND [p].[LARCType] IS NULL
				THEN [c].[Removal_LARC]
			ELSE [p].[LARCType]
			END Previous_Larc,
		CASE 
			WHEN c.Removal_LARC = 'IUD'
				AND c.LARCType IN ('IUS', 'IUD')
				THEN '3'
			WHEN c.Removal_LARC = c.LARCType
				OR c.Removal_LARC2 = c.LARCType
				THEN '3' -- Maintain
			WHEN c.Removal_LARC <> c.LARCType
				OR c.Removal_LARC2 <> c.LARCType
				THEN '2' -- Change
			WHEN c.Insertion_LARC = c.LARCType
				OR c.Insertion_LARC2 = c.LARCType
				THEN '1' -- New
			ELSE '1' --New
			END Contraception_Method,
		[c].[PatientID],
		[c].[ReferralID],
		[c].[ActivityID],
		[c].[UniqueID],
		[c].[ReferralDate],
		[c].[BookedDate],
		c.ActivityDate,
		p.ActivityDate Previous_Larc_Date,
		[c].[Activity],
		[c].[ServiceName],
		[c].[AppointmentStatus],
		[c].[AppointmentOutcome],
		[c].[AppointmentOutcomeReason],
		[c].[ProcedurePerformed],
		[c].[Fee],
		[c].[MFF],
		[c].[Total_Fee_Including_MFF],
		[c].[PricingActivity],
		[c].[rwn],
		ROW_NUMBER() OVER (
			PARTITION BY c.UniqueID ORDER BY p.ActivityDate DESC
			) rwn2 -- Used to remove more then 1 previous larc date.
	FROM Contra_Method c
	LEFT OUTER JOIN Contra_Method p --Getting previous LARC Methods to pick up any changes
		ON c.PatientID = p.PatientID
			AND c.ActivityDate > p.ActivityDate
	WHERE c.rwn = 1
	),
LARC -- Tidying up the report
AS (
	SELECT *
	FROM (
		SELECT CASE 
				WHEN p2.[UniqueID] IS NOT NULL -- Replacing Collection appointment with a near telemed Appointment
					THEN p2.UniqueID
				WHEN p3.[UniqueID] IS NOT NULL -- Replacing blank appointment with a near telemed Appointment
					THEN p3.UniqueID
				ELSE [p].[LARC_UniqueID]
				END Appointment_UniqueID,
			Coalesce(CASE 
					WHEN p2.[UniqueID] IS NOT NULL
						THEN p2.Activity
					WHEN p3.[UniqueID] IS NOT NULL
						THEN p3.Activity
					ELSE [p].[Blank_Activity]
					END, [p].[Insertion_Activity], [p].[Removal_Activity]) [Appointment_Activity],
			[p].[Current_Larc],
			[p].[Previous_Larc],
			CASE 
				WHEN p.Previous_Larc IS NOT NULL
					AND p.[Previous_Larc] <> p.[Current_Larc]
					THEN '2' --Change
				WHEN p.Previous_Larc IS NOT NULL
					AND p.[Previous_Larc] = p.[Current_Larc]
					THEN '3' --Maintain
				ELSE [p].[Contraception_Method]
				END Contraception_Method,
			[p].[PatientID],
			[p].[ReferralID],
			[p].[ActivityID],
			[p].[UniqueID],
			[p].[ReferralDate],
			[p].[BookedDate],
			[p].[ActivityDate],
			[p].[Previous_Larc_Date],
			[p].[Activity],
			[p].[ServiceName],
			[p].[AppointmentStatus],
			[p].[AppointmentOutcome],
			[p].[AppointmentOutcomeReason],
			[p].[ProcedurePerformed],
			[p].[Fee],
			[p].[MFF],
			[p].[Total_Fee_Including_MFF],
			[p].[PricingActivity],
			[p].[rwn],
			[p].[rwn2],
			ROW_NUMBER() OVER (
				PARTITION BY p.UniqueID ORDER BY p2.Activity
				) rwn3
		FROM Previous_Larc p
		LEFT OUTER JOIN Appointments p2 -- replacing any collection with approximate Telemded appointment
			ON p.ReferralID = p2.ReferralID
				AND p2.Activity = 'Telemedicine MA'
				AND p.Blank_Activity = 'Telemedicine Collection'
				AND DATEDIFF(day, p2.ActivityDate, p.ActivityDate) <= 14
		LEFT OUTER JOIN Appointments p3 -- replacing any blank appointments with approximate Telemded appointment
			ON p.ReferralID = p3.ReferralID
				AND p3.Activity IN ('Telemedicine MA', 'MA Treatment', 'LARC')
				AND p.Blank_Activity IS NULL
				AND DATEDIFF(day, p3.ActivityDate, p.ActivityDate) <= 20
		WHERE p.rwn2 = 1
		) p
	WHERE rwn3 = 1
		AND Appointment_UniqueID IS NOT NULL
	),
LARC_NO_MED
AS (
	SELECT ROW_NUMBER() OVER (
			PARTITION BY p.ActivityID ORDER BY p.ActivityDate,
				p.ProcedurePerformed DESC
			) rwn,
		[p].[PatientID],
		[p].[ReferralID],
		[p].[ActivityID],
		[p].[UniqueID],
		[p].[ReferralDate],
		[p].[BookedDate],
		[p].[ActivityDate],
		[p].[Activity],
		[p].[ServiceName],
		[p].[AppointmentStatus],
		[p].[AppointmentOutcome],
		[p].[AppointmentOutcomeReason],
		[p].[ProcedurePerformed],
		[p].[TestResults],
		[p].[SourceType],
		[p].[GestationDaysAtActivity],
		[p].[GestValue],
		[p].[Fee],
		[p].[MFF],
		[p].[Total_Fee_Including_MFF],
		[p].[PricingActivity]
	FROM autom.PatientActivityDaily p
	LEFT JOIN pbi.[Location] l
		ON p.Hospital = l.Hospital
	WHERE p.ActivityDate >= '2024-04-01'
		AND p.ActivityDate <= '2025-03-31'
		AND AppointmentStatus IN ('Seen', 'Awaiting Result', 'Supplied', 'Discharged', 'Arrived', 'Administered', 'Admitted', 'Result Received')
		AND NOT AppointmentOutcome IN ('Rebook Required', 'Right Care required')
		AND NOT l.[Status] = 'Non-MSI'
		AND NOT p.SourceType IN ('Medication', 'Pathology', 'HIV & Syphilis')
		AND Activity IN ('LARC', 'LARC Consultation')
	),
Convert_Larc
AS (
	SELECT replace(CASE 
			WHEN l.ProcedurePerformed LIKE '%Insertion%'
				OR insertion.ProcedurePerformed IS NOT NULL
				THEN coalesce(insertion.ProcedurePerformed, l.ProcedurePerformed)
			ELSE NULL
			END, ' Insertion', '') Insertion,
	replace(CASE 
			WHEN l.ProcedurePerformed LIKE '%Removal%'
				OR Removal.ProcedurePerformed IS NOT NULL
				THEN coalesce(Removal.ProcedurePerformed, l.ProcedurePerformed)
			ELSE NULL
			END, ' Removal', '') Removal,
	CASE 
		WHEN Removal.PricingActivity LIKE '%Fitting%'
			THEN replace(Removal.PricingActivity, 'Fitting only - ', '')
		WHEN insertion.PricingActivity = 'Fitting Only' --Fit only and insertion is not null
			AND replace(CASE 
					WHEN l.ProcedurePerformed LIKE '%Insertion%'
						OR insertion.ProcedurePerformed IS NOT NULL
						THEN coalesce(insertion.ProcedurePerformed, l.ProcedurePerformed)
					ELSE NULL
					END, ' Insertion', '') IS NOT NULL
			THEN NULL
		ELSE replace(insertion.PricingActivity, 'Fitting only - ', '')
		END Current_LARC,
	CASE 
		WHEN insertion.PricingActivity LIKE '%Removal%'
			THEN replace(insertion.PricingActivity, ' Removal', '')
		ELSE replace(Removal.PricingActivity, ' Removal', '')
		END Previous_LARC,
	l.*
FROM LARC_NO_MED l
LEFT OUTER JOIN LARC_NO_MED insertion
	ON l.PatientID = insertion.PatientID
		AND l.ActivityDate = insertion.ActivityDate
		AND insertion.ProcedurePerformed LIKE '%Insertion%'
LEFT OUTER JOIN LARC_NO_MED Removal
	ON l.PatientID = Removal.PatientID
		AND l.ActivityDate = Removal.ActivityDate
		AND Removal.ProcedurePerformed LIKE '%Removal%'
WHERE l.rwn = 1

	),
LARC_Activity
AS (
	SELECT CASE 
			WHEN c.Previous_LARC = c.Current_LARC
				THEN '3'
			WHEN c.Previous_LARC <> c.Current_LARC
				THEN '2'
			WHEN c.Insertion = c.Removal
				THEN '3'
			WHEN c.Insertion <> c.Removal
				THEN '2'
			WHEN c.Removal IS NULL
				AND c.Insertion IS NOT NULL
				THEN '1'
			ELSE NULL
			END Contraception_Method,
		CASE 
			WHEN c.Insertion IS NULL
				AND c.Removal IS NOT NULL
				AND c.Previous_LARC = 'IUD'
				THEN '21'
			WHEN c.Insertion IS NULL
				AND c.Removal IS NOT NULL
				AND c.Previous_LARC = 'Implant'
				THEN '19'
			WHEN c.Insertion IS NULL
				AND c.Removal IS NOT NULL
				AND c.Previous_LARC = 'IUS'
				THEN '20'
			WHEN c.Insertion IS NULL
				AND c.Removal = 'Implant'
				THEN '19'
			WHEN c.Insertion IS NULL
				AND c.Removal IS NOT NULL
				AND c.Previous_LARC IS NULL
				THEN '00' --For Removal
			ELSE '01'
			END SRHA_Activity,
		*
	FROM Convert_Larc c
	WHERE (
			NOT c.Previous_LARC LIKE '%Fitting%'
			OR c.Previous_LARC IS NULL
			)
		AND (
			NOT c.Current_LARC LIKE '%Removal%'
			OR c.Current_LARC IS NULL
			)
	),
Main_Report_Dtbr -- Duplicate to be removed
AS (
	SELECT 'NTG' [Organisation ID],
		p.NHSLocation [Clinic ID],
		p.PatientID [Patient ID],
		CASE 
			WHEN p.Sex = 'Female'
				THEN '2'
			WHEN p.Sex = 'Male'
				THEN '1'
			WHEN p.ServiceName = 'TOP'
				THEN '2'
			WHEN p.ServiceName = 'VAS'
				THEN '1'
			ELSE 'X'
			END [Gender],
		CASE 
			WHEN p.AgeAtActivity IS NULL
				THEN datediff(year, p.DOB, p.ActivityDate)
			ELSE p.AgeAtActivity
			END [Age],
		p.NHSEthnicity [Ethnicity],
		CASE 
			WHEN pc.[LSOA21] IS NULL
				THEN 'X99999999'
			ELSE pc.[LSOA21]
			END [LSOA of Residence],
		CASE 
			WHEN pc.OSLAUA IS NULL
				THEN 'X99999999'
			ELSE pc.[OSLAUA]
			END [LA of Residence],
		CASE 
			WHEN coalesce(p.EligibilityPracticeCode, p.ReferralPracticeCode, p.PatientPracticeCode, 'V81999') IN ('78255', '31230', 'H83044', 'H83044001', 'J6X4D', 'D8O5E', 'P5V9W')
				THEN 'V81999'
			ELSE coalesce(p.EligibilityPracticeCode, p.ReferralPracticeCode, p.PatientPracticeCode, 'V81999')
			END [GP Practice Code],
		p.ActivityDate [Date of Attendance],
		CASE 
			WHEN p.Activity LIKE '%second%'
				THEN 'N'
			WHEN p.Activity LIKE '%2nd%'
				THEN 'N'
			WHEN p.Activity LIKE '%Cons%'
				THEN 'Y'
			ELSE 'N'
			END [Initial Contact],
		CASE 
			WHEN p.Activity LIKE '%phone%'
				OR p.Activity LIKE '%Tele%'
				THEN '02'
			ELSE '01'
			END [Consultation Medium Used],
		CASE 
			WHEN p.Activity LIKE '%phone%'
				OR p.Activity LIKE '%Tele%'
				THEN 'A01'
			ELSE 'B01'
			END [Location Type],
		Coalesce(l.Contraception_Method, la.Contraception_Method) [Contraception Method Status],
		CASE 
			WHEN Coalesce(l.Current_Larc, la.Current_Larc) = 'Injectable Contraception'
				THEN '01'
			WHEN Coalesce(l.Current_Larc, la.Current_Larc) = 'Implant'
				THEN '02'
			WHEN Coalesce(l.Current_Larc, la.Current_Larc) = 'IUD'
				THEN '03'
			WHEN Coalesce(l.Current_Larc, la.Current_Larc) = 'IUS'
				THEN '04'
			WHEN Coalesce(l.Current_Larc, la.Current_Larc) = 'Vaginal Ring'
				THEN '05'
			WHEN Coalesce(l.Current_Larc, la.Current_Larc) = 'Contraception Patch'
				THEN '06'
			WHEN Coalesce(l.Current_Larc, la.Current_Larc) = 'Combined Pill'
				THEN '07'
			WHEN Coalesce(l.Current_Larc, la.Current_Larc) = 'POP'
				THEN '08'
			ELSE Coalesce(l.Current_Larc, la.Current_Larc) --NULL
			END [Contraception Main Method],
		'' [Contraception Other Method 1],
		'' [Contraception Other Method 2],
		'' [Contraception Method Post Coital 1],
		'' [Contraception Method Post Coital 2],
		Coalesce (Case 	
	WHEN p.ServiceName = 'Counselling' AND p.Activity = 'Holistic Counselling' AND p.ProcedurePerformed IS NULL Then '00'
	WHEN p.ServiceName = 'Counselling' AND p.Activity = 'Holistic Counselling' AND p.ProcedurePerformed IS NULL Then '00'
	WHEN p.ServiceName = 'TOP' AND p.Activity like '%Ultrasound%' Then '27' -- Newley added 2025-06-11
	WHEN p.ServiceName = 'LARC' AND p.Activity = 'CHLAMYDIA TRACHOMATIS URINE' AND p.ProcedurePerformed IS NULL Then '34'
	WHEN p.ServiceName = 'LARC' AND p.Activity = 'HIV ANTIBODIES' AND p.ProcedurePerformed IS NULL Then '34'
	WHEN p.ServiceName = 'LARC' AND p.Activity = 'NEISSERIA GONORRHOEA SWAB' AND p.ProcedurePerformed IS NULL Then '34'
	WHEN p.ServiceName = 'LARC' AND p.Activity = 'SYPHILIS ANTIBODIES' AND p.ProcedurePerformed IS NULL Then '34'
	WHEN p.ServiceName = 'TOP' AND p.Activity = '2nd MA appt' AND p.ProcedurePerformed = 'Medical Abortion' Then '06'
	WHEN p.ServiceName = 'TOP' AND p.Activity = '2nd MA appt' AND p.ProcedurePerformed IS NULL Then '06'
	WHEN p.ServiceName = 'TOP' AND p.Activity = 'BPAS Phone Consultation' AND p.ProcedurePerformed IS NULL Then '04'
	WHEN p.ServiceName = 'TOP' AND p.Activity = 'BPAS Sameday F2F Consultation' AND p.ProcedurePerformed IS NULL Then '04'
	WHEN p.ServiceName = 'TOP' AND p.Activity = 'BPAS Sameday MA Treatment'  Then '06'
	WHEN p.ServiceName = 'TOP' AND p.Activity = 'CHLAMYDIA TRACHOMATIS SWAB' AND p.ProcedurePerformed IS NULL Then '34'
	WHEN p.ServiceName = 'TOP' AND p.Activity = 'CHLAMYDIA TRACHOMATIS URINE' AND p.ProcedurePerformed IS NULL Then '34'
	WHEN p.ServiceName = 'TOP' AND p.Activity = 'CHLAMYDIA/ GONORRHOEA PCR SWAB  ' AND p.ProcedurePerformed IS NULL Then '34'
	WHEN p.ServiceName = 'TOP' AND p.Activity = 'CHLAMYDIA/ GONORRHOEA PCR URINE' AND p.ProcedurePerformed IS NULL Then '34'
	WHEN p.ServiceName = 'TOP' AND p.Activity = 'Consent' AND p.ProcedurePerformed IS NULL Then '00'
	WHEN p.ServiceName = 'TOP' AND p.Activity = 'Counselling Post Treatment' AND p.ProcedurePerformed IS NULL Then '10'
	WHEN p.ServiceName = 'TOP' AND p.Activity = 'Counselling Pre-Treatment' AND p.ProcedurePerformed IS NULL Then '05'
	WHEN p.ServiceName = 'TOP' AND p.Activity = 'ERPC' AND p.ProcedurePerformed = 'ERPC' Then '00'
	WHEN p.ServiceName = 'TOP' AND p.Activity = 'ERPC' AND p.ProcedurePerformed IS NULL Then '00'
	WHEN p.ServiceName = 'TOP' AND p.Activity = 'ERPC' AND p.ProcedurePerformed = 'STOP <12w (1hr prep)' Then '07'
	WHEN p.ServiceName = 'TOP' AND p.Activity = 'ERPC' AND p.ProcedurePerformed = 'STOP 15 to 18+6w (3hrs prep)' Then '07'
	WHEN p.ServiceName = 'TOP' AND p.Activity = 'Extended F2F Consultation' AND p.ProcedurePerformed IS NULL Then '04'
	WHEN p.ServiceName = 'TOP' AND p.Activity = 'Extended MA Treatment' AND p.ProcedurePerformed = 'Medical Abortion' Then '06'
	WHEN p.ServiceName = 'TOP' AND p.Activity = 'Extended MA Treatment' AND p.ProcedurePerformed IS NULL Then '06'
	WHEN p.ServiceName = 'TOP' AND p.Activity = 'F2F Consultation' AND p.ProcedurePerformed IS NULL Then '04'
	WHEN p.ServiceName = 'TOP' AND p.Activity = 'F2F Counselling Post Treatment' AND p.ProcedurePerformed IS NULL Then '10'
	WHEN p.ServiceName = 'TOP' AND p.Activity = 'F2F Counselling Pre-Treatment' AND p.ProcedurePerformed IS NULL Then '05'
	WHEN p.ServiceName = 'TOP' AND p.Activity = 'Failed MA - Repeat Medical' AND p.ProcedurePerformed IS NULL Then '06'
	WHEN p.ServiceName = 'TOP' AND p.Activity = 'HIV & SYPHILIS ANTIBODIES' AND p.ProcedurePerformed IS NULL Then '34'
	WHEN p.ServiceName = 'TOP' AND p.Activity = 'HIV ANTIBODIES' AND p.ProcedurePerformed IS NULL Then '34'
	WHEN p.ServiceName = 'TOP' AND p.Activity = 'Intra-Uterine Contraceptive Device (T-Safe 380)' AND p.ProcedurePerformed = 'STOP 12+1 to 14+6w (1.5hrs prep)' Then '07'
	WHEN p.ServiceName = 'TOP' AND p.Activity = 'MA Post Check Appointment' AND p.ProcedurePerformed IS NULL Then '08'
	WHEN p.ServiceName = 'TOP' AND p.Activity = 'MA Treatment' Then '06'
	WHEN p.ServiceName = 'TOP' AND p.Activity = 'MA Treatment with LARC' Then '06'
	WHEN p.ServiceName = 'TOP' AND p.Activity = 'NEISSERIA GONORRHOEA SWAB' AND p.ProcedurePerformed IS NULL Then '34'
	WHEN p.ServiceName = 'TOP' AND p.Activity = 'NEISSERIA GONORRHOEA URINE' AND p.ProcedurePerformed IS NULL Then '34'
	WHEN p.ServiceName = 'TOP' AND p.Activity = 'Overnight Prep' AND p.ProcedurePerformed IS NULL Then '00'
	WHEN p.ServiceName = 'TOP' AND p.Activity = 'Phone Consultation' AND p.ProcedurePerformed IS NULL Then '04'
	WHEN p.ServiceName = 'TOP' AND p.Activity = 'Post Treatment Appointment' AND p.ProcedurePerformed = 'Medical Abortion' Then '06'
	WHEN p.ServiceName = 'TOP' AND p.Activity = 'Post Treatment Appointment' AND p.ProcedurePerformed IS NULL Then '08'
	WHEN p.ServiceName = 'TOP' AND p.Activity = 'Pre Assessment' AND p.ProcedurePerformed = 'Medical Abortion' Then '06'
	WHEN p.ServiceName = 'TOP' AND p.Activity = 'Pre Assessment' AND p.ProcedurePerformed IS NULL Then '00'
	WHEN p.ServiceName = 'TOP' AND p.Activity = 'Sameday Phone Consultation' AND p.ProcedurePerformed IS NULL Then '04'
	WHEN p.ServiceName = 'TOP' AND p.Activity = 'Scan only appointment' AND p.ProcedurePerformed = 'Medical Abortion' Then '06'
	WHEN p.ServiceName = 'TOP' AND p.Activity = 'Scan only appointment' AND p.ProcedurePerformed IS NULL Then '27'
	WHEN p.ServiceName = 'TOP' AND p.Activity = 'Second F2F consultation' AND p.ProcedurePerformed IS NULL Then '04'
	WHEN p.ServiceName = 'TOP' AND p.Activity = 'Second Phone Consultation' AND p.ProcedurePerformed IS NULL Then '04'
	WHEN p.ServiceName = 'TOP' AND p.Activity = 'STOP <12w (1hr prep)' AND p.ProcedurePerformed = 'ERPC' Then '00'
	WHEN p.ServiceName = 'TOP' AND p.Activity = 'STOP <12w (1hr prep)' Then '07'
	WHEN p.ServiceName = 'TOP' AND p.Activity = 'STOP 12+1 to 14+6w (1.5hrs prep)' AND p.ProcedurePerformed = 'ERPC' Then '00'
	WHEN p.ServiceName = 'TOP' AND p.Activity = 'STOP 12+1 to 14+6w (1.5hrs prep)' Then '07'
	WHEN p.ServiceName = 'TOP' AND p.Activity = 'STOP 15 to 18+6w (3hrs prep)'  Then '07'
	WHEN p.ServiceName = 'TOP' AND p.Activity = 'STOP 19 to 21+6w'  Then '07'
	WHEN p.ServiceName = 'TOP' AND p.Activity = 'STOP 22w to 23+6w' Then '07'
	WHEN p.ServiceName = 'TOP' AND p.Activity = 'Surgical Treatment GA 0w to 14w' AND p.ProcedurePerformed = 'STOP <12w (1hr prep)' Then '07'
	WHEN p.ServiceName = 'TOP' AND p.Activity = 'SYPHILIS ANTIBODIES' AND p.ProcedurePerformed IS NULL Then '34'
	WHEN p.ServiceName = 'TOP' AND p.Activity = 'Telemedicine Collection' AND l.Previous_Larc is not null Then '01'
	WHEN p.ServiceName = 'TOP' AND p.Activity = 'Telemedicine Collection' AND p.ProcedurePerformed = 'Medical Abortion' Then '06'
	WHEN p.ServiceName = 'TOP' AND p.Activity = 'Telemedicine Collection' Then '00'
	WHEN p.ServiceName = 'TOP' AND p.Activity = 'Telemedicine Eligibility Check'Then '06'
	WHEN p.ServiceName = 'TOP' AND p.Activity = 'Telemedicine MA' Then '06'
	WHEN p.ServiceName = 'VAS' AND p.Activity = 'Counselling Pre-Treatment' AND p.ProcedurePerformed IS NULL Then '00'
	WHEN p.ServiceName = 'VAS' AND p.Activity = 'Extended F2F Consultation' AND p.ProcedurePerformed IS NULL Then '14'
	WHEN p.ServiceName = 'VAS' AND p.Activity = 'Phone Consultation' AND p.ProcedurePerformed IS NULL Then '14'
	WHEN p.ServiceName = 'VAS' AND p.Activity = 'Post Treatment Appointment' AND p.ProcedurePerformed IS NULL Then '16'
	WHEN p.ServiceName = 'VAS' AND p.Activity = 'Post Treatment Appointment' AND p.ProcedurePerformed = 'Vasectomy' Then '15'
	WHEN p.ServiceName = 'VAS' AND p.Activity = 'VAS 2nd Cons' AND p.ProcedurePerformed IS NULL Then '14'
	WHEN p.ServiceName = 'VAS' AND p.Activity = 'VAS Consultation' AND p.ProcedurePerformed IS NULL Then '14'
	WHEN p.ServiceName = 'VAS' AND p.Activity = 'VAS Re-op' AND p.ProcedurePerformed IS NULL Then '15'
	WHEN p.ServiceName = 'VAS' AND p.Activity = 'VAS Re-op' AND p.ProcedurePerformed = 'Vasectomy' Then '15'
	WHEN p.ServiceName = 'VAS' AND p.Activity = 'VAS Re-op' AND p.ProcedurePerformed = 'Vasectomy Re-Op' Then '15'
	WHEN p.ServiceName = 'VAS' AND p.Activity = 'VAS Treatment' AND p.ProcedurePerformed IS NULL Then '15'
	WHEN p.ServiceName = 'VAS' AND p.Activity = 'VAS Treatment' AND p.ProcedurePerformed = 'Vasectomy' Then '15'
	WHEN l.Previous_Larc = 'Implant' then '19'
	WHEN l.Previous_Larc = 'IUS' then '20'
	WHEN l.Previous_Larc = 'IUD' then '21'
	--when l.Previous_Larc is null and p.ProcedurePerformed
	WHEN p.Activity = 'LARC' and l.Current_Larc is not null then '01'
	WHEN p.Activity = 'LARC Consultation'  and l.Current_Larc is not null then  '01'
	end, la.SRHA_Activity) [SRH Care Activity 1],
		'' [SRH Care Activity 2],
		'' [SRH Care Activity 3],
		'' [SRH Care Activity 4],
		'' [SRH Care Activity 5],
		'' [SRH Care Activity 6],
		p.Activity,
		p.UniqueID,
		p.Fee,
		p.PricingActivity,
		p.ProcedurePerformed,
		p.ServiceName,
		p.SourceType,
		p.Hospital,
		p.MonitoringContracts
	FROM autom.PatientActivityDaily p
	LEFT OUTER JOIN [ref].[NHS_Current_Gridlink_Postcode_Directory] pc
		ON replace(pc.PCDS, ' ', '') = Upper(REPLACE(p.PatientPostCode, ' ', ''))
	LEFT OUTER JOIN pbi.[Location] h
		ON p.Hospital = h.Hospital
	LEFT OUTER JOIN LARC l
		ON l.Appointment_UniqueID = p.UniqueID
	LEFT OUTER JOIN LARC_Activity la
		ON la.UniqueID = p.UniqueID
	WHERE p.ActivityDate >= '2024-04-01'
		AND p.ActivityDate <= '2025-03-31'
		AND p.AppointmentStatus IN ('Seen', 'Awaiting Result', 'Supplied', 'Discharged', 'Arrived', 'Administered', 'Admitted', 'Result Received')
		AND NOT h.[Status] = 'Non-MSI'
		AND NOT p.SourceType IN ('Medication')
	),
initial_contact
AS (
	SELECT *
	FROM (
		SELECT ROW_NUMBER() OVER (
				PARTITION BY patientId ORDER BY ActivityDate ASC
				) rwn_initial,
			uniqueid Initial_Contact_Fix
		FROM autom.PatientActivityDaily
		) r
	WHERE rwn_initial = 1
	)


SELECT DISTINCT [r].[Organisation ID],
	case when replace([r].[Clinic ID],'', '') = 'S6N8G' then 'W7T1Z' else replace([r].[Clinic ID],'', '')  end [Clinic ID], --Clinic on the NHS side is showing closed before the activity, I had to post it to another location near by
	[r].[Patient ID],
	CASE 
		WHEN [r].[Contraception Main Method] IS NOT NULL
			AND [r].[Gender] = '1'
			THEN 'X'
		WHEN [SRH Care Activity 1] IN ('02', '04', '06', '07', '08', '09', '11', '18', '19', '20', '21', '22', '23', '24', '25', '26', '29', '35', '36', '37')
			AND [r].[Gender] = '1'
			THEN 'X'
		ELSE [r].[Gender]
		END [Gender],
	[r].[Age],
	[r].[Ethnicity],
	CASE 
		WHEN [r].[LSOA of Residence] IS NULL
			OR [r].[LSOA of Residence] = ''
			THEN 'X99999999'
		ELSE [r].[LSOA of Residence]
		END [LSOA of Residence],
	CASE 
		WHEN [r].[LA of Residence] IS NULL
			OR [r].[LA of Residence] = ''
			THEN 'X99999999'
		ELSE [r].[LA of Residence]
		END [LA of Residence],
	[r].[GP Practice Code],
	[r].[Date of Attendance],
	CASE 
		WHEN Initial_Contact_Fix IS NOT NULL
			THEN 'Y'
		ELSE 'N'
		END [Initial Contact],
	[r].[Consultation Medium Used],
	[r].[Location Type],
	isnull(CASE 
			WHEN [r].[Contraception Main Method] IS NULL
				THEN NULL
			ELSE [r].[Contraception Method Status]
			END, '') [Contraception Method Status],
	isnull([r].[Contraception Main Method], '') [Contraception Main Method],
	[r].[Contraception Other Method 1],
	[r].[Contraception Other Method 2],
	[r].[Contraception Method Post Coital 1],
	[r].[Contraception Method Post Coital 2],
	[r].[SRH Care Activity 1],
	[r].[SRH Care Activity 2],
	[r].[SRH Care Activity 3],
	[r].[SRH Care Activity 4],
	[r].[SRH Care Activity 5],
	[r].[SRH Care Activity 6]
FROM (SELECT DISTINCT *,
		ROW_NUMBER() OVER (
			PARTITION BY m.UniqueID ORDER BY m.[Contraception Method Status] DESC,
				m.[Contraception Main Method] ASC
			) rwn
	FROM Main_Report_Dtbr m
	LEFT OUTER JOIN initial_contact i
		ON i.Initial_Contact_Fix = m.uniqueID
	WHERE NOT MonitoringContracts IN ('MS UK Staff LARC', 'MSI Staff LARC', 'MSI UK Discounted Private', 'MSI UK Private Counselling', 'MSI UK Private LARC', 'MSI UK Private TOP', 'MSI UK Private VAS', 'NHS NORTHERN IRELAND CCG TOP') -- Removing all NON NHS
	) r
WHERE rwn = 1
	AND NOT r.[SRH Care Activity 1] IN ('00' /*, '27'*/)
	AND r.[SRH Care Activity 1] IS NOT NULL
 	AND [Patient ID] <> '2255979' -- out of area client
	and not [r].[Clinic ID] in ('I4N2C','NTG36') -- Location closed before the activity, only showing a few lines activity for ultrasound
	--and [Contraception Main Method] like '%fit%'

/*
select top 100 * from LARC 
where PatientID = '2376047'*/
--LARC_Activity --where PatientID = '2376047'


--select * from Previous_Larc where patientid = '2376047'
--select * from Appointments where patientid = '2376047'
--select * from meds where patientid = '2376047'
--select * from Contra_Method where patientid = '2376047'
--select * from Previous_Larc where patientid = '2376047'
--select * from LARC where patientid = '2376047'
--select * from LARC_NO_MED where patientid = '2376047'
--select top 100 * from Convert_Larc

--select * from Convert_Larc where patientid = '2376047'
--select * from LARC_Activity where patientid in ( '2223532','2376047')
--select * from Main_Report_Dtbr where [Patient ID] =   '2376047'
--select * from initial_contact where patientid = '2376047'
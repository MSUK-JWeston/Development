WITH Activity
AS (
	SELECT cpci.c_val AS PatientID,
		sahs.c_comme,
		aptstatusbh.TEXT,
		sba.id,
		sahs.id AS sahs_id,
		sahs.schl_booking_appoin_apptstatu3,
		cast(sba.appointmen AS DATE) AS AppointmentDate,
		cast(sahs.apptdate AS DATE) OriginalAppointmentDate,
		sba.currentsta,
		StatusReason.TEXT AS StatusReason,
		CancelledReason.TEXT AS CancelledReason,
		ROW_NUMBER() OVER (
			PARTITION BY sba.id ORDER BY sba.sys_creation_datetime
			) AS RowNum,
		--	cpci.c_val AS PatientID,
		referral.id ReferralID,
		sba.id AS ActivityID,
		CAST(ROW_NUMBER() OVER (
				PARTITION BY sba.id ORDER BY sba.sys_creation_datetime
				) AS VARCHAR(255)) + CASE 
			WHEN opp.SBAID IS NOT NULL
				THEN 'OPP'
			WHEN ipp.SBAID IS NOT NULL
				THEN 'IPP'
			ELSE 'OP'
			END + CAST(sba.id AS VARCHAR(255)) AS UniqueID,
		CAST(cr.dateofrefe AS DATE) AS ReferralDate,
		CAST(sba.sys_creation_datetime AS DATE) AS BookedDate,
		CAST(sba.appointmen AS DATE) AS ActivityDate,
		ISNULL(ca.name, cp2.proceduren) AS Activity,
		ai.[text] AS AnaestheticType,
		cl.name ActivityLocation,
		cs.servicenam ServiceName,
		CASE 
			WHEN (
					COALESCE(CASE 
							WHEN IPDeferred.TEXT LIKE '%-%'
								THEN SUBSTRING(IPDeferred.TEXT, 1, CHARINDEX('-', IPDeferred.TEXT) - 2)
							ELSE IPDeferred.TEXT
							END, AptOutcome.[text], StatusReason.TEXT) LIKE '%DNP%'
					OR COALESCE(CASE 
							WHEN IPDeferred.TEXT LIKE '%-%'
								THEN SUBSTRING(IPDeferred.TEXT, 1, CHARINDEX('-', IPDeferred.TEXT) - 2)
							ELSE IPDeferred.TEXT
							END, AptOutcome.[text], StatusReason.TEXT) LIKE '%Did not proceed%'
					)
				AND NOT AptStatus.TEXT = 'Not Seen'
				THEN 'DNP'
			WHEN IPDeferred.TEXT IS NOT NULL
				THEN 'Deferred'
			WHEN COALESCE(CASE 
						WHEN IPDeferred.TEXT LIKE '%-%'
							THEN SUBSTRING(IPDeferred.TEXT, 1, CHARINDEX('-', IPDeferred.TEXT) - 2)
						ELSE IPDeferred.TEXT
						END, AptOutcome.[text], StatusReason.TEXT) LIKE '%DNA%'
				THEN 'DNA'
			ELSE AptStatus.TEXT
			END AppointmentStatus,
		COALESCE(CASE 
				WHEN IPDeferred.TEXT LIKE '%-%'
					THEN SUBSTRING(IPDeferred.TEXT, 1, CHARINDEX('-', IPDeferred.TEXT) - 2)
				ELSE IPDeferred.TEXT
				END, AptOutcome.[text], StatusReason.TEXT) AppointmentOutcome,
		COALESCE(CASE 
				WHEN IPDeferred.TEXT LIKE '%-%'
					THEN SUBSTRING(IPDeferred.TEXT, CHARINDEX('-', IPDeferred.TEXT) + 2, LEN(IPDeferred.TEXT))
				ELSE NULL
				END, AptOutcomeReason.[text], CancelledReason.TEXT) AppointmentOutcomeReason,
		COALESCE(opp.PerformedOutpatientProcedure, ipp.PerformedInpatientProcedure) AS ProcedurePerformed,
		CAST(NULL AS VARCHAR(255)) TestResults,
		CASE 
			WHEN opp.SBAID IS NOT NULL
				THEN 'Outpatient Procedure'
			WHEN ipp.SBAID IS NOT NULL
				THEN 'Inpatient'
			ELSE 'Outpatient'
			END SourceType,
		aptstatusbhcs.TEXT AS CurrentStatusText,
		StatusReasoncs.TEXT AS CurrentStatusReason,
		CancelledReasoncs.TEXT AS CurrentStatusCancelledReason,
		case when sba.currentsta = sahs.id
			then 'Y'
			else 'N'
			end as Current_Booking
	FROM schl_booking_appoin sba -- Bookings
	LEFT OUTER JOIN core_activity ca
		ON sba.activity = ca.id -- Activity/ Appointment Types
	LEFT OUTER JOIN schl_theatrebooking st
		ON sba.theatreboo = st.id -- Inpatient bookings
	LEFT OUTER JOIN core_procedure cp2
		ON st.c_procedu = cp2.id -- Planned Procedure
	LEFT OUTER JOIN applookup_instance ai
		ON st.lkp_anaestheti = ai.id --Aneas for Inpatent; Billing
	LEFT OUTER JOIN core_patient_c_identifi cpci
		ON sba.patient = cpci.id -- Maxims Patient ID
			AND cpci.lkp_c_ty = - 1905
			AND cpci.merged IS NULL
	LEFT OUTER JOIN schl_sch_session sss
		ON sba.c_sessi = sss.id -- Bookings session details
	LEFT OUTER JOIN schl_prof sp
		ON sss.sch_profil = sp.id -- Join for Locations
	LEFT OUTER JOIN core_location cl
		ON sp.hospital = cl.id -- Hospital Locations
	LEFT OUTER JOIN core_dischargedepis discevent
		ON sba.pasevent = discevent.pasevent -- Outcomes of Inpatients
	LEFT OUTER JOIN core_services cs
		ON sss.service = cs.id -- Service type from Booking
	LEFT OUTER JOIN applookup_instance AptStatus
		ON sba.lkp_apptstatus = AptStatus.id -- Booking Status
	LEFT OUTER JOIN applookup_instance AptOutcome
		ON sba.lkp_outcome = AptOutcome.id -- Booking Outcome for Outpatients & Outpatients Procedure
	LEFT OUTER JOIN applookup_instance AptOutcomeReason
		ON sba.lkp_outcomerea = AptOutcomeReason.id -- Booking Outcome Reasons for Outpatients & Outpatients Procedure
	LEFT OUTER JOIN applookup_instance IPDeferred
		ON discevent.lkp_dereferred = IPDeferred.id -- Inpatient outcome; DNP or Deferred
	LEFT OUTER JOIN care_catsreferral referral
		ON sba.care_catsreferral_appointmen = referral.id -- Referral Details
	LEFT OUTER JOIN core_referralletter cr
		ON referral.referralde = cr.id -- Referral Further Details
	LEFT OUTER JOIN schl_appt_history_s sahs
		ON sba.id = sahs.schl_booking_appoin_apptstatu3 -- Booking Status History
	LEFT OUTER JOIN applookup_instance StatusReason
		ON sahs.lkp_statusreas = StatusReason.id -- Status Reason booking history
	LEFT JOIN applookup_instance aptstatusbh
		ON sahs.lkp_status = aptstatusbh.id -- Booking Status History
	LEFT OUTER JOIN applookup_instance CancelledReason
		ON sahs.lkp_cancellati = CancelledReason.id -- Status Cancellation Reason booking history
	LEFT OUTER JOIN schl_appt_history_s sahcs
		ON sba.currentsta = sahcs.id -- Booking Status History
	LEFT OUTER JOIN applookup_instance StatusReasoncs
		ON sahcs.lkp_statusreas = StatusReasoncs.id -- Status Reason booking history
	LEFT JOIN applookup_instance aptstatusbhcs
		ON sahcs.lkp_status = aptstatusbhcs.id -- Booking Status History
	LEFT OUTER JOIN applookup_instance CancelledReasoncs
		ON sahcs.lkp_cancellati = CancelledReasoncs.id -- Status Cancellation Reason booking history
	LEFT OUTER JOIN [pa].RefOutpatientProcedure opp
		ON opp.SBAID = sba.id
	LEFT OUTER JOIN [pa].RefInpatientProcedure ipp
		ON sba.id = ipp.SBAID
	WHERE sba.rie IS NULL
		AND CAST(sahs.apptdate AS DATE) >= '2025-05-03' /*
	AND CAST(sahs.statuschan AS DATE) = CAST(sahs.apptdate AS DATE)*/
		/*	AND cast(sahs.apptdate AS DATE) >= '2025-06-03'
		AND CAST(sba.appointmen AS DATE) >= DATEADD(day, 1, CAST(sahs.apptdate AS DATE)) --Getting appointments for the next day
		--AND sba.id = 2015472
		--AND cpci.c_val IN ('2416746', '2416562', '2416605', '2416589', '2416619', '2416565', '2416604', '2416549', '2416564', '2415815', '2383232', '1957182', '2415313', '2414815', '2415837', '1615235', '2415843', '2415846', '2416568', '2416937', '2416590', '1145283', '2415288', '2415226', '1878655', '2294901', '2415327', '2415320', '2414983', '2415593', '2415702', '2415521', '2415630', '2415062', '2274688', '2415377', '2416470', '2105755', '2332055', '2415298')
		--and  cpci.c_val  = '2416549'
		AND aptstatusbh.TEXT = 'Cancelled'
		AND StatusReason.TEXT = 'Provider Cancelled'*/
		---AND cs.servicenam = 'TOP'
	)
SELECT  c.PatientID,
	c.StatusReason,
	c.CancelledReason,
	c.OriginalAppointmentDate,
	c.AppointmentDate,
	c.Activity,
	c.ServiceName,
	c.CurrentStatusText,
    c.Current_Booking
FROM Activity c
WHERE Activity IN ('Counselling Post Treatment', 'Counselling Pre-Treatment')
and c.OriginalAppointmentDate <='2025-06-06' -- Change this date as needed
--and Current_Booking = 'Y'
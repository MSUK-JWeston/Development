WITH ir
AS (
	SELECT cpi.c_val Client_ID,
		ci.catsreferr Referral_ID,
		FORMAT(CAST(crl.dateofrefe AS DATE), 'yyyy-MM-dd') Referral_Date,
		ci.id IR_ID,
		CASE 
			WHEN CHARINDEX(' -', ai1.[text]) <> 0
				THEN TRIM(REPLACE(SUBSTRING(ai1.[text], CHARINDEX(' -', ai1.[text]) + 1, LEN(ai1.[text])), '- ', ''))
			ELSE ai1.[text]
			END Team,
		CASE 
			WHEN CHARINDEX(' -', ai1.[text]) <> 0
				THEN TRIM(SUBSTRING(ai1.[text], 1, CHARINDEX(' -', ai1.[text])))
			ELSE ai1.[text]
			END [Location],
		--ai1.[text] [Team_Location],
		ai2.[text] [Type],
		ai3.[text] Request_Reason,
		ai4.[text] Reqquest_Status,
		ci.recordingirecordingd Request_DateTime,
		CAST(ci.recordingirecordingd AS DATE) Request_Date,
		cms.nameforename + ' ' + cms.namesurname Request_Recording_User,
		REPLACE(ci.comments, CHAR(10), '|') Request_Comments,
		cs.servicenam [Service],
		eec.[name] [Contract_Name]
	FROM care_internalreques ci
	LEFT OUTER JOIN applookup_instance ai1
		ON ci.lkp_team = ai1.id
	LEFT OUTER JOIN core_patient cp
		ON ci.patient = cp.id
	LEFT JOIN core_memberofstaff cms
		ON ci.recordingirecordingu = cms.id
	LEFT OUTER JOIN applookup_instance ai2
		ON ci.lkp_requesttyp = ai2.id
	LEFT OUTER JOIN applookup_instance ai3
		ON ci.lkp_requestrea = ai3.id
	LEFT OUTER JOIN core_patient_c_identifi cpi
		ON cp.id = cpi.id
			AND lkp_c_ty = '-1905'
	LEFT JOIN care_catsreferral ccr
		ON ci.catsreferr = ccr.id
	LEFT JOIN core_referralletter crl
		ON ccr.referralde = crl.id
	LEFT JOIN core_services cs
		ON crl.service = cs.id
	LEFT JOIN elig_contracteligib ece
		ON ccr.id = ece.referral
	LEFT JOIN elig_eligcontractco eec
		ON ece.eligibilit = eec.id
	LEFT JOIN care_internalreque4 cir
		ON ci.currentsta = cir.id
	LEFT JOIN applookup_instance ai4
		ON cir.lkp_status = ai4.id
	WHERE ci.recordingirecordingd >= '2025-06-02' --DATEADD(qq, DATEDIFF(qq, 0, GETDATE()) - 1, 0)
		----AND ci.recordingirecordingd  <= DATEADD(dd, -1, DATEADD(qq, DATEDIFF(qq, 0, GETDATE()), 0)))
		AND (
			cp.nameforename NOT LIKE 'DummyICABForename'
			AND cp.namesurname NOT LIKE 'DummyICABSurname'
			)
		----AND
		--cpi.c_val = 2175618
	)
SELECT *
FROM ir
WHERE [Location] = 'OneCall'
	AND [Type] LIKE '%lead%'
	AND request_reason = 'Please listen to recording'
	/*AND (
		Request_Comments LIKE '%save%'
		OR Request_Comments LIKE '%maxim%'
		)*/
	AND team = 'Centre Operations'
--	and Client_ID ='2415437'



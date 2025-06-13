WITH Hospitals
AS (
	SELECT *,
		ROW_NUMBER() OVER (
			PARTITION BY h.Hospital ORDER BY volume DESC,
				LastActivityDate DESC
			) rwn
	FROM (
		SELECT NHSLocation,
			Hospital,
			HospitalType,
			sum(1) Volume,
			max(ActivityDate) AS LastActivityDate
		FROM autom.PatientActivityDaily
		WHERE HospitalType <> 'Other'
		GROUP BY Hospital,
			HospitalType,
			NHSLocation
		) h
	),
Update_List
AS (
	SELECT h.*,
		h2.NHSLocation AS Main_NHSLocation,
		h2.HospitalType AS Main_HospitalType,
		h2.volume AS Main_Volume,
		h2.volume - h.Volume AS Volume_Difference
	FROM Hospitals h
	LEFT JOIN Hospitals h2
		ON h.Hospital = h2.Hospital
			AND h2.rwn = 1
	WHERE h.rwn <> 1
	) 

	/*
UPDATE autom.PatientActivityDaily
SET NHSLocation = ul.Main_NHSLocation,
	HospitalType = ul.Main_HospitalType
FROM autom.PatientActivityDaily p
INNER JOIN Update_List ul
	ON p.Hospital = ul.Hospital*/
SELECT *
FROM Hospitals

--AND p.NHSLocation = ul.NHSLocation
/*
update autom.PatientActivityDaily
set NHSLocation = 'Z1R9J'
where Hospital = 'Dagenham VAS'*/
UPDATE autom.PatientActivityDaily
SET NHSLocation = 'NTG0I'
WHERE Hospital = 'Hemsworth VAS'

UPDATE autom.PatientActivityDaily
SET NHSLocation = 'S6N8G'
WHERE Hospital = 'Frimley Green CTC'

UPDATE autom.PatientActivityDaily
SET NHSLocation = 'A9N6M'
WHERE Hospital = 'Edmonton CTC'

UPDATE autom.PatientActivityDaily
SET NHSLocation = 'Q3K5B'
WHERE Hospital = 'Liverpool CTC'

UPDATE autom.PatientActivityDaily
SET NHSLocation = 'P9G3I'
WHERE Hospital = 'Manchester Central CTC'

;


WITH age
AS (
	SELECT AgeAtActivity,
		DOB,
		UniqueID,
		PatientID
	FROM maxims_pa.PatientActivity
	WHERE PatientID IN ('2084657', '2157904', '2125478', '2167699', '2172811', '2213193', '2213304', '2219608', '2226329', '2228760', '2240152', '2241715', '2249370', '2251322', '2255025', '2255058', '2255468', '2257571', '2257634', '2258569', '2263817', '2263821', '2264634', '2267271', '2269028', '2273000', '2275105', '2275766', '2277161', '2281025', '2298623', '2299334', '2304117', '2304828', '2311989', '2312871', '2317143', '2317699', '2324151', '2324874', '2328612', '2329897', '2330625', '2332960', '2333514', '2340850', '2342255', '2353987', '2364813', '2368013', '2371543', '2372804', '2377950')
	)
UPDATE autom.PatientActivityDaily
SET AgeAtActivity = age.AgeAtActivity,
	DOB = age.DOB
FROM autom.PatientActivityDaily AS pad
INNER JOIN age
	ON pad.UniqueID = age.UniqueID;


update autom.PatientActivityDaily
set PatientGPCode = 'S78010'
where uniqueID = '1OP1523677'
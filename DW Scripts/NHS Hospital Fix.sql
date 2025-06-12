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
	) /*
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

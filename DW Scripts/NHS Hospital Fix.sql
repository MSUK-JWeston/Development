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
	)/*
UPDATE autom.PatientActivityDaily
SET NHSLocation = ul.Main_NHSLocation,
	HospitalType = ul.Main_HospitalType
FROM autom.PatientActivityDaily p
INNER JOIN Update_List ul
	ON p.Hospital = ul.Hospital*/

    select * FROM Hospitals
		--AND p.NHSLocation = ul.NHSLocation
		/*
update autom.PatientActivityDaily
set NHSLocation = 'Z1R9J'
where Hospital = 'Dagenham VAS'*/



update autom.PatientActivityDaily
set NHSLocation = 'NTG0I'
where Hospital = 'Hemsworth VAS'

update autom.PatientActivityDaily
set NHSLocation = 'S6N8G'
where Hospital = 'Frimley Green CTC'

update autom.PatientActivityDaily
set NHSLocation = 'A9N6M'
where Hospital = 'Edmonton CTC'





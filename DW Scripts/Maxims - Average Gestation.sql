WITH Activity_Gestation_Days
AS (
	SELECT format(ActivityDate, 'yyyy') Year,
		pad.GestationDaysAtActivity gest,
		at.InterventionType
	FROM autom.PatientActivityDaily pad
	LEFT JOIN ref.ActivityTypes at
		ON at.Activity = pad.Activity
	WHERE pad.Treatment_Flag = 'Y'
		AND servicename = 'TOP'
	),
Piv
AS (
	SELECT year,
		[Telemedicine],
		[MA Treatment],
		[Surgical]
	FROM Activity_Gestation_Days ready
	-- Pivot the data to get average gestation days by intervention type
	PIVOT(AVG(gest) FOR InterventionType IN ([Telemedicine], [MA Treatment], [Surgical])) AS pvt
	)
-- Convert days to 'X weeks Y days' format
SELECT year,
	CONCAT (
		FLOOR([Telemedicine] / 7),
		'w ',
		[Telemedicine] % 7,
		'd'
		) AS [Telemedicine],
	CONCAT (
		FLOOR([MA Treatment] / 7),
		'w ',
		[MA Treatment] % 7,
		'd'
		) AS [MA Treatment],
	CONCAT (
		FLOOR([Surgical] / 7),
		'w ',
		[Surgical] % 7,
		'd'
		) AS [Surgical]
FROM Piv

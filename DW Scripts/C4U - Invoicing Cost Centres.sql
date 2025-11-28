ALTER PROC pbi.C4U_Invoicing @StartDate DATE,
	@EndDate DATE
AS
SELECT DISTINCT [a].[ID],
	[a].[Hospital],
	isnull([c].[Cost_Centre], a.[Cost Centre]) AS [Cost Centre],
	[a].[DateTimeExtract]
FROM c4u.audit a
LEFT JOIN ref.Hospital_Cost_Centre c
	ON a.Hospital = c.Hospital
WHERE CAST(a.DateTimeExtract AS DATE) >= @StartDate
	AND Cast(a.DateTimeExtract AS DATE) <= @EndDate

--4. Tournament Trends
--Player Progression: Performance improvement/decrease of top players across stages.
WITH StagePerformance AS (
    SELECT 
        Player, Tournament, Stage,
        SUM(Kills) AS Total_Kills, SUM(Deaths) AS Total_Deaths, SUM(Assists) AS Total_Assists,
		CAST(SUM(Kills) *1.0 / SUM(Deaths) as decimal (10,2)) AS KD_Ratio
    FROM players_stats
    GROUP BY Player, Tournament, Stage
),
PerformanceProgression AS (
    SELECT 
        Player, Tournament, Stage, KD_Ratio,
        LAG(KD_Ratio) OVER (PARTITION BY Player ORDER BY Stage) AS Previous_Stage_KD,
        ROUND(KD_Ratio - LAG(KD_Ratio) OVER (PARTITION BY Player ORDER BY Stage), 2) AS KD_Change
    FROM StagePerformance
)
SELECT 
    Player, Tournament, Stage, KD_Ratio AS Current_Stage_KD,
    Previous_Stage_KD, KD_Change AS KD_Progression
FROM PerformanceProgression
WHERE KD_Change IS NOT NULL
ORDER BY Player, Tournament, Stage

--Historical Context: Comparing tournament outcomes with past seasons.
SELECT Tournament, Match_Name, CONCAT(Team_A_Score, ':' ,Team_B_Score) AS Final_Score, Match_Result
FROM scores
WHERE Match_Type = 'Grand Final'
ORDER BY Tournament

--Team Strategy Evolution: Changes in team compositions
SELECT Tournament, Stage, Match_Type, Map, Team, STRING_AGG(Agent, ', ') AS Team_Compoitions
FROM teams_picked_agents
WHERE Stage != 'All Stages'
GROUP BY Tournament, Stage,  Match_Type, Map, Team
ORDER BY Team, Map
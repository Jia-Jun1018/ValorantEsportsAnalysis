--3. Match and Map Insights
--Map Win Patterns: Trends in win rates for attack/defense across all tournaments.
SELECT Tournament, Stage, Map, CAST(SUM(Team_A_Attacker_Score + Team_B_Attacker_Score) * 1.0 /
         SUM(Team_A_Attacker_Score + Team_B_Attacker_Score + Team_A_Defender_Score + Team_B_Defender_Score)
         AS DECIMAL(10,2)) AS Attack_Win_Rate,   
    CAST(SUM(Team_A_Defender_Score + Team_B_Defender_Score) * 1.0 /
         SUM(Team_A_Attacker_Score + Team_B_Attacker_Score + Team_A_Defender_Score + Team_B_Defender_Score)
         AS DECIMAL(10,2)) AS Defense_Win_Rate
FROM maps_scores
GROUP BY Tournament, Stage, Map


--Map-Specific Duration: Maps with the shortest/longest match durations.
SELECT Map, MIN(Duration) AS Shortest_Duration, MAX(Duration) AS Longest_Duration
FROM maps_scores
GROUP BY Map

--Most played maps
SELECT Map, COUNT(Map) AS Total_Played
FROM maps_stats
WHERE Map NOT LIKE 'All%' AND Stage NOT LIKE 'All Stages'
GROUP BY Map
ORDER BY COUNT(Map) DESC



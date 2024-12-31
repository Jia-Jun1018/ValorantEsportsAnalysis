--5. Player of the Year
-- Key Player of the Year (most 3,4,5k and clutches win)
SELECT TOP 1 Eliminator AS Player, Eliminator_Team AS Team,
	COUNT(CASE WHEN kill_type = '3k' THEN 1 ELSE NULL END) AS '3k_Count',
	COUNT(CASE WHEN kill_type = '4k' THEN 1 ELSE NULL END) AS '4k_Count',
	COUNT(CASE WHEN kill_type = '5k' THEN 1 ELSE NULL END) AS '5k_Count',
	   -- Weighted Score Calculation
    (COUNT(CASE WHEN kill_type = '3k' THEN 1 ELSE NULL END) * 2) +
    (COUNT(CASE WHEN kill_type = '4k' THEN 1 ELSE NULL END) * 4) +
    (COUNT(CASE WHEN kill_type = '5k' THEN 1 ELSE NULL END) * 6) AS Total_Score
FROM rounds_kills
GROUP BY Eliminator, Eliminator_Team
ORDER BY Total_Score DESC

--Clutch Player of the Year (win most clutches)
SELECT TOP 1 Eliminator AS Player, Eliminator_Team AS Team,
	COUNT(CASE WHEN kill_type = '1v1' THEN 1 ELSE NULL END) AS '1v1_Count',
	COUNT(CASE WHEN kill_type = '1v2' THEN 1 ELSE NULL END) AS '1v2_Count',
	COUNT(CASE WHEN kill_type = '1v3' THEN 1 ELSE NULL END) AS '1v3_Count',
	(COUNT(CASE WHEN kill_type = '1v1' THEN 1 ELSE NULL END) * 1) +
    (COUNT(CASE WHEN kill_type = '1v2' THEN 1 ELSE NULL END) * 3) +
    (COUNT(CASE WHEN kill_type = '1v3' THEN 1 ELSE NULL END) * 5) AS Total_Score
FROM rounds_kills
GROUP BY Eliminator, Eliminator_Team
ORDER BY Total_Score DESC

--Entry Fragger of the Year (Most First Blood)
SELECT TOP 1 Player, Teams, SUM(Rounds_Played) AS Rounds_Played,
	SUM(First_Kills) AS Total_First_Kills,
	CAST(SUM(First_Kills) *1.0/SUM(Rounds_Played) AS decimal (10,2)) AS First_Kill_Per_Round
FROM players_stats
GROUP BY Player, Teams
ORDER BY First_Kill_Per_Round DESC

--Assist Master of the Year (Most Assist)
SELECT TOP 1 Player, Teams, SUM(Rounds_Played) AS Rounds_Played,
	SUM(Assists) AS Total_Assists,
	CAST(SUM(Assists) *1.0/SUM(Rounds_Played) AS decimal (10,2)) AS Assist_Per_Round
FROM players_stats
GROUP BY Player, Teams
ORDER BY Assist_Per_Round DESC

--MVP by KD Ratio
SELECT TOP 1 Player, Teams, 
	CAST(SUM(Kills)*1.0/SUM(Deaths) as decimal (10,2)) AS KD_Ratio
FROM players_stats
GROUP BY Player, Teams
ORDER BY KD_Ratio DESC

--Defender of the year
SELECT Top 1 Player, Team, SUM(Kills) AS Total_Defense_Side_Kills
FROM overview
WHERE Side = 'defend'
GROUP BY Player, Team
ORDER BY Total_Defense_Side_Kills DESC

--Attacker of the year
SELECT TOP 1 Player, Team, SUM(Kills) AS Total_Attack_Side_Kills
FROM overview
WHERE Side = 'attack'
GROUP BY Player, Team
ORDER BY Total_Attack_Side_Kills DESC

--Top Damage Dealer
SELECT TOP 1 Player, Team, AVG(Average_Damage_Per_Round) AS Average_Damage_Per_Round
FROM overview
WHERE Side != 'both'
GROUP BY Player, Team
ORDER BY Average_Damage_Per_Round DESC

-- Most Picked Agent per Map
WITH Agent_Pick_Count AS (
    SELECT Map, Agent,
        COUNT(*) AS Agent_Pick_Count, COUNT(*) AS Total_Maps_Played
    FROM teams_picked_agents
    GROUP BY Map, Agent
),
Ranked_Agents AS (
    SELECT Map, Agent, SUM(Agent_Pick_Count) AS Total_Picks,
        RANK() OVER (PARTITION BY Map ORDER BY SUM(Agent_Pick_Count) DESC) AS Rank
    FROM Agent_Pick_Count
    GROUP BY Map, Agent
)
SELECT 
    Map,
    Agent AS Most_Picked_Agent,
    Total_Picks
FROM Ranked_Agents
WHERE Rank = 1
ORDER BY Map;

--Most Picked Agents By Roles
WITH Agent_Pick_Count AS (
    SELECT Tournament, Stage, Match_Type, Agent,
    COUNT(*) AS Agent_Pick_Count
    FROM teams_picked_agents
	WHERE Stage = 'All Stages'
    GROUP BY Tournament, Stage, Match_Type, Agent
),
Agent_Role AS (
    SELECT Agent,
        CASE 
            WHEN Agent IN ('Phoenix', 'Jett', 'Reyna', 'Raze', 'Yoru', 'Neon', 'Iso') THEN 'Duelist'
            WHEN Agent IN ('Sova', 'Breach', 'Skye', 'Kayo', 'Fade', 'Gekko') THEN 'Initiator'
            WHEN Agent IN ('Killjoy', 'Cypher', 'Sage', 'Chamber', 'Deadlock') THEN 'Sentinel'
            WHEN Agent IN ('Brimstone', 'Viper', 'Omen', 'Astra', 'Harbor', 'Clove') THEN 'Controller'
            ELSE 'Unknown' 
        END AS Role
    FROM teams_picked_agents
    GROUP BY Agent
),
Ranked_Agents AS (
    SELECT ar.Role, ar.Agent,
        SUM(Agent_Pick_Count) AS Total_Picks,
        RANK() OVER (PARTITION BY Role ORDER BY SUM(Agent_Pick_Count) DESC) AS Rank
    FROM Agent_Pick_Count arc
    JOIN Agent_Role ar
        ON arc.Agent = ar.Agent
    GROUP BY ar.Role, ar.Agent
)
SELECT Role, Agent AS Most_Picked_Agent, Total_Picks
FROM Ranked_Agents
WHERE Rank = 1
ORDER BY Role;

# Portfolio
# Valorant Esports Analysis Using SQL
# Part 1: Player Performance
# Top Fragger Analysis: Players with the most kills per tournament stage.
WITH PlayerKills AS (
    SELECT Tournament, Stage, Player, Teams, SUM(kills) AS Total_Kills
    FROM players_stats
	WHERE Stage = 'All Stages'
    GROUP BY tournament, stage, player, teams),

TopFraggers AS (
    SELECT Tournament, Stage, Player, Teams, Total_Kills,
        RANK() OVER (PARTITION BY tournament, stage ORDER BY total_kills DESC) AS rank
    FROM PlayerKills)

SELECT *
FROM TopFraggers
WHERE rank = 1;

# Consistency Rating: Players with the lowest death-per-round (DPR) and high kill-per-round (KPR) metrics.
WITH PlayerPerformance AS (
	SELECT tournament, stage, player, teams,
        ROUND(CAST(SUM(kills) AS FLOAT) / SUM(rounds_played),2) AS kill_per_round,
        ROUND(CAST(SUM(deaths) AS FLOAT) / SUM(rounds_played),2) AS death_per_round
    FROM players_stats
	WHERE Stage = 'All Stages'
    GROUP BY tournament, stage, player, teams),

RankedPlayers AS (
    SELECT Tournament, Stage, Player, Teams, Kill_per_Round, Death_per_Round,
        RANK() OVER (PARTITION BY tournament, stage ORDER BY kill_per_round DESC, death_per_round ASC) AS Consistency_Rank
    FROM PlayerPerformance)

SELECT *
FROM RankedPlayers
WHERE consistency_rank <= 10;


# Agent Specialization: Most successful players by agent, measured by win rate and ACS.
WITH AgentPerformance AS (
SELECT ps.Player, ps.Teams, ps.Agents, ps.Tournament, ps.Stage, AVG(ps.average_combat_score) AS Average_Combat_Score,
	CAST(COUNT(CASE 
              WHEN ps.teams = LEFT(s.match_result, CHARINDEX(' won', s.match_result)) THEN 1
              END) * 100.0 / COUNT(*) AS int) AS win_rate
FROM players_stats ps
JOIN scores s ON ps.tournament = s.tournament 
        AND ps.stage = s.stage 
        AND ps.teams = s.team_a
GROUP BY ps.Player, ps.Teams, ps.Agents, ps.Tournament, ps.Stage),

BestPlayerByAgent AS(
SELECT Player, Teams, Agents, Tournament, Stage, Average_Combat_Score, Win_Rate,
	RANK() OVER (PARTITION BY Agents ORDER BY Win_Rate DESC, Average_Combat_Score DESC) AS Rank
FROM AgentPerformance)

SELECT *
FROM BestPlayerByAgent
WHERE Rank = 1 AND Agents NOT LIKE '%,%'

# Performance in Key Rounds: Impact of players in clutch rounds (e.g., 1vX situations).
SELECT Player, Team, SUM(_1v1 + _1v2 + _1v3) AS Clutch_Numbers, SUM(_1v1 + _1v2 + _1v3) * 100 / COUNT(*) AS Clutch_Success_Rate
FROM kills_stats
GROUP BY player, team
ORDER BY SUM(_1v1 + _1v2 + _1v3) DESC, SUM(_1v1 + _1v2 + _1v3) * 100 / COUNT(*) DESC

# First Blood Impact: Players with the highest success rate in securing first kills and surviving.
WITH FirstKillsAndSurvive AS (
	SELECT Player, Teams, Tournament, Stage, SUM(First_Kills) AS Total_First_Kills,
		CASE WHEN SUM(First_Kills) > 0 THEN SUM(First_kills-First_deaths)*100 / SUM(First_kills) 
				ELSE 0 END AS Survival_After_First_Blood_Rate
	FROM players_stats
	WHERE Stage = 'All Stages'
	GROUP BY Player, Teams, Tournament, Stage),

FirstBloodAndSurviveRank AS (
	SELECT Player, Teams, Tournament, Stage, Total_First_Kills, Survival_After_First_Blood_Rate,
		RANK() OVER (PARTITION BY Tournament, Stage ORDER BY Total_First_Kills DESC, Survival_After_First_Blood_Rate DESC) AS Rank
	FROM FirstKillsAndSurvive)

SELECT *
FROM FirstBloodAndSurviveRank
WHERE Rank = 1 AND tournament NOT LIKE '%China%'



# Damage Efficiency: Players with the highest average damage per round (ADR).
WITH HighestADR AS (
	SELECT Player, Teams, Tournament, Stage, AVG(average_damage_per_round) AS Total_ADR
	FROM players_stats
	WHERE Stage = 'All Stages'
	GROUP BY Player, Teams, Tournament, Stage),

HighestADRRank AS (
	SELECT Player, Teams, Tournament, Stage, Total_ADR,
		Rank() OVER(PARTITION BY Tournament, Stage ORDER BY Total_ADR DESC) AS Rank
	FROM HighestADR)

SELECT *
FROM HighestADRRank
WHERE Rank = 1 AND Tournament NOT LIKE '%China%'

# Part 2: Team Performance
# Clutch Round Success: Teams winning the most 1vX situations.
SELECT Team, SUM(_1v1 + _1v2 + _1v3) AS Clutch_Numbers
FROM kills_stats
GROUP BY team
ORDER BY SUM(_1v1 + _1v2 + _1v3) DESC

# Side-Specific Dominance: Teams with the best win rates as attackers/defenders per map.
WITH SideSpecificPerformance AS (
    SELECT 
        map,
        team_a AS team,
        'attacker' AS side,
        SUM(team_a_attacker_score) AS rounds_won,
        SUM(team_a_attacker_score + team_b_defender_score) AS total_rounds_played
    FROM maps_scores
    GROUP BY map, team_a

    UNION ALL

    SELECT 
        map,
        team_a AS team,
        'defender' AS side,
        SUM(team_a_defender_score) AS rounds_won,
        SUM(team_a_defender_score + team_b_attacker_score) AS total_rounds_played
    FROM maps_scores
    GROUP BY map, team_a

    UNION ALL

    SELECT 
        map,
        team_b AS team,
        'attacker' AS side,
        SUM(team_b_attacker_score) AS rounds_won,
        SUM(team_b_attacker_score + team_a_defender_score) AS total_rounds_played
    FROM maps_scores
    GROUP BY map, team_b

    UNION ALL

    SELECT 
        map,
        team_b AS team,
        'defender' AS side,
        SUM(team_b_defender_score) AS rounds_won,
        SUM(team_b_defender_score + team_a_attacker_score) AS total_rounds_played
    FROM maps_scores
    GROUP BY map, team_b
),
WinRates AS (
    SELECT 
        map,
        team,
        side,
        SUM(rounds_won) * 1.0 / SUM(total_rounds_played) AS win_rate
    FROM SideSpecificPerformance
    GROUP BY map, team, side
),
BestTeams AS (
    SELECT 
        map,
        team,
        side,
        win_rate,
        RANK() OVER (PARTITION BY map, side ORDER BY win_rate DESC) AS rank
    FROM WinRates
)
SELECT 
    Map,
    Side,
    team AS Best_Team,
    ROUND(CAST((win_rate * 100) AS decimal (10,2)), 2) AS Best_Win_Rate
FROM BestTeams
WHERE rank = 1
ORDER BY map, side;


# Agent Strategy Efficiency: Teams with the highest win rate using specific agent compositions.
WITH AgentCompWinRate AS (
SELECT Tournament, Stage, Map, Team, STRING_AGG(Agent , ',' ) AS AgentComposition, COUNT(*)/5 AS total_maps_played,
        SUM(total_wins_by_map)/5 AS total_wins,
        CAST((SUM(total_wins_by_map) / SUM(total_maps_played))*100 AS DECIMAL (10,2)) AS win_rate
    FROM teams_picked_agents
	WHERE Stage = 'All Stages'
	GROUP BY tournament, stage, map, team ),

BestComp AS (
SELECT Tournament, Stage, Map, Team, AgentComposition, Total_Maps_Played, Total_Wins, Win_Rate,
	RANK() OVER (PARTITION BY AgentComposition ORDER BY Win_Rate DESC, Total_Wins DESC) AS Rank
	FROM AgentCompWinRate)

SELECT *
FROM BestComp
WHERE Rank = 1 and Total_Wins != 0
ORDER BY Win_Rate DESC


# Map Control: Teams excelling in rounds where the spike is planted but not detonated. (Defense)
WITH DefuseCount AS (
	SELECT Tournament, Stage, Map, Team, SUM(Defused)-SUM(Detonated) AS Defense_Success
	FROM win_loss_methods_count
	GROUP BY Tournament, Stage, Map, Team ),

DefuseRank AS (
	SELECT Tournament, Stage, Map, Team, Defense_Success,
		RANK() OVER(PARTITION BY Map ORDER BY Defense_Success DESC) AS RANK
	FROM DefuseCount  )

SELECT *
FROM DefuseRank
WHERE RANK = 1


# Map Control: Teams excelling in rounds where the spike is planted and detonated. (Attack)
WITH PlantCount AS (
	SELECT Tournament, Stage, Map, Team, SUM(Defused_Failed)-SUM(Detonation_Denied) AS Detonation
	FROM win_loss_methods_count
	GROUP BY Tournament, Stage, Map, Team ),

AttackRank AS (
	SELECT Tournament, Stage, Map, Team, Detonation,
		RANK() OVER(PARTITION BY Map ORDER BY Detonation DESC) AS RANK
	FROM PlantCount  )

SELECT *
FROM AttackRank
WHERE RANK = 1

# Part 3: Match and Map Insights
# Map Win Patterns: Trends in win rates for attack/defense across all tournaments.
SELECT Tournament, Stage, Map, CAST(SUM(Team_A_Attacker_Score + Team_B_Attacker_Score) * 1.0 /
         SUM(Team_A_Attacker_Score + Team_B_Attacker_Score + Team_A_Defender_Score + Team_B_Defender_Score)
         AS DECIMAL(10,2)) AS Attack_Win_Rate,   
    CAST(SUM(Team_A_Defender_Score + Team_B_Defender_Score) * 1.0 /
         SUM(Team_A_Attacker_Score + Team_B_Attacker_Score + Team_A_Defender_Score + Team_B_Defender_Score)
         AS DECIMAL(10,2)) AS Defense_Win_Rate
FROM maps_scores
GROUP BY Tournament, Stage, Map


# Map-Specific Duration: Maps with the shortest/longest match durations.
SELECT Map, MIN(Duration) AS Shortest_Duration, MAX(Duration) AS Longest_Duration
FROM maps_scores
GROUP BY Map

# Most played maps
SELECT Map, COUNT(Map) AS Total_Played
FROM maps_stats
WHERE Map NOT LIKE 'All%' AND Stage NOT LIKE 'All Stages'
GROUP BY Map
ORDER BY COUNT(Map) DESC

# Part 4: Tournament Trends
# Player Progression: Performance improvement/decrease of top players across stages.
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

# Historical Context: Comparing tournament outcomes with past seasons.
SELECT Tournament, Match_Name, CONCAT(Team_A_Score, ':' ,Team_B_Score) AS Final_Score, Match_Result
FROM scores
WHERE Match_Type = 'Grand Final'
ORDER BY Tournament

# Team Strategy Evolution: Changes in team compositions
SELECT Tournament, Stage, Match_Type, Map, Team, STRING_AGG(Agent, ', ') AS Team_Compoitions
FROM teams_picked_agents
WHERE Stage != 'All Stages'
GROUP BY Tournament, Stage,  Match_Type, Map, Team
ORDER BY Team, Map

# Part 5: Player of the Year
# Key Player of the Year (most 3,4,5k and clutches win)
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

# Clutch Player of the Year (win most clutches)
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

# Entry Fragger of the Year (Most First Blood)
SELECT TOP 1 Player, Teams, SUM(Rounds_Played) AS Rounds_Played,
	SUM(First_Kills) AS Total_First_Kills,
	CAST(SUM(First_Kills) *1.0/SUM(Rounds_Played) AS decimal (10,2)) AS First_Kill_Per_Round
FROM players_stats
GROUP BY Player, Teams
ORDER BY First_Kill_Per_Round DESC

# Assist Master of the Year (Most Assist)
SELECT TOP 1 Player, Teams, SUM(Rounds_Played) AS Rounds_Played,
	SUM(Assists) AS Total_Assists,
	CAST(SUM(Assists) *1.0/SUM(Rounds_Played) AS decimal (10,2)) AS Assist_Per_Round
FROM players_stats
GROUP BY Player, Teams
ORDER BY Assist_Per_Round DESC

# MVP by KD Ratio
SELECT TOP 1 Player, Teams, 
	CAST(SUM(Kills)*1.0/SUM(Deaths) as decimal (10,2)) AS KD_Ratio
FROM players_stats
GROUP BY Player, Teams
ORDER BY KD_Ratio DESC

# Defender of the year
SELECT Top 1 Player, Team, SUM(Kills) AS Total_Defense_Side_Kills
FROM overview
WHERE Side = 'defend'
GROUP BY Player, Team
ORDER BY Total_Defense_Side_Kills DESC

# Attacker of the year
SELECT TOP 1 Player, Team, SUM(Kills) AS Total_Attack_Side_Kills
FROM overview
WHERE Side = 'attack'
GROUP BY Player, Team
ORDER BY Total_Attack_Side_Kills DESC

# Top Damage Dealer
SELECT TOP 1 Player, Team, AVG(Average_Damage_Per_Round) AS Average_Damage_Per_Round
FROM overview
WHERE Side != 'both'
GROUP BY Player, Team
ORDER BY Average_Damage_Per_Round DESC

# Most Picked Agent per Map
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

# Most Picked Agents By Roles
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

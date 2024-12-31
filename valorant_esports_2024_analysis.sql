--1. Player Performance
--Top Fragger Analysis: Players with the most kills per tournament stage.
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

--Consistency Rating: Players with the lowest death-per-round (DPR) and high kill-per-round (KPR) metrics.
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


--Agent Specialization: Most successful players by agent, measured by win rate and ACS.
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

--Performance in Key Rounds: Impact of players in clutch rounds (e.g., 1vX situations).
SELECT Player, Team, SUM(_1v1 + _1v2 + _1v3) AS Clutch_Numbers, SUM(_1v1 + _1v2 + _1v3) * 100 / COUNT(*) AS Clutch_Success_Rate
FROM kills_stats
GROUP BY player, team
ORDER BY SUM(_1v1 + _1v2 + _1v3) DESC, SUM(_1v1 + _1v2 + _1v3) * 100 / COUNT(*) DESC

--First Blood Impact: Players with the highest success rate in securing first kills and surviving.
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



--Damage Efficiency: Players with the highest average damage per round (ADR).
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
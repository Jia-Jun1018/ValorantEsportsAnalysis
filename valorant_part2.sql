--2. Team Performance
--Clutch Round Success: Teams winning the most 1vX situations.
SELECT Team, SUM(_1v1 + _1v2 + _1v3) AS Clutch_Numbers
FROM kills_stats
GROUP BY team
ORDER BY SUM(_1v1 + _1v2 + _1v3) DESC

--Side-Specific Dominance: Teams with the best win rates as attackers/defenders per map.
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


--Agent Strategy Efficiency: Teams with the highest win rate using specific agent compositions.
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


--Map Control: Teams excelling in rounds where the spike is planted but not detonated. (Defense)
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


--Map Control: Teams excelling in rounds where the spike is planted and detonated. (Attack)
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

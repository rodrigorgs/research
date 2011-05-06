--
-- List of projects
--
SELECT name, description
FROM products

--
-- List of projects/components
--
SELECT prod.name, comp.name
FROM products prod
INNER JOIN components comp ON comp.product_id = prod.id

--
-- List of projects, ranked by number of bugs
--
SELECT prod.name, COUNT(*) AS total
FROM products prod
INNER JOIN components comp ON comp.product_id = prod.id
INNER JOIN bugs bug ON bug.component_id = comp.id
GROUP BY prod.name
ORDER BY total DESC

--
-- List of projects/components, ranked by number of bugs (sorted by project)
--
SELECT prod.name, comp.name, COUNT(*) AS total
FROM products prod
INNER JOIN components comp ON comp.product_id = prod.id
INNER JOIN bugs bug ON bug.component_id = comp.id
GROUP BY prod.name, comp.name
ORDER BY  prod.name ASC, total DESC, comp.name ASC

--
-- List of projects/components, ranked by number of bugs
--
SELECT prod.name, comp.name, COUNT(*) AS total
FROM products prod
INNER JOIN components comp ON comp.product_id = prod.id
INNER JOIN bugs bug ON bug.component_id = comp.id
GROUP BY prod.name, comp.name
ORDER BY total DESC

--
-- List of projects/components, ranked by number VERIFIED bugs
--
SELECT prod.name, comp.name, COUNT(*) AS total
FROM products prod
INNER JOIN components comp ON comp.product_id = prod.id
INNER JOIN bugs bug ON bug.component_id = comp.id
WHERE bug.bug_status = 'VERIFIED'
GROUP BY prod.name, comp.name
ORDER BY total DESC

--
-- All bugs have at least one activity
-- (i.e., this query returns empty)
--
SELECT DISTINCT a.bug_id, b.bug_id 
FROM bugs_activity a, bugs b
WHERE a.bug_id IS NULL 
OR b.bug_id IS NULL  

--
-- Most active bugs inside Mylyn/Core
--
SELECT bug.bug_id, COUNT(*) AS total, bug.creation_ts, bug.reporter, bug.bug_severity
FROM products prod
INNER JOIN components comp ON comp.product_id = prod.id
INNER JOIN bugs bug ON bug.component_id = comp.id
INNER JOIN bugs_activity act ON act.bug_id = bug.bug_id
WHERE prod.name = 'Mylyn'
AND comp.name = 'Core'
GROUP BY bug.bug_id
ORDER BY total DESC

--
-- Activity for a specific bug
-- 
SELECT bug.bug_id, act.who, act.bug_when, field.name, act.added, act.removed
FROM products prod
INNER JOIN components comp ON comp.product_id = prod.id
INNER JOIN bugs bug ON bug.component_id = comp.id
INNER JOIN bugs_activity act ON act.bug_id = bug.bug_id
INNER JOIN fielddefs field ON field.id = act.fieldid
WHERE prod.name = 'Mylyn'
AND comp.name = 'Core'
AND bug.bug_id = 120499 --100629
ORDER BY bug.bug_id, bug_when

--
-- Comments on a specific bug
-- 
SELECT bug.bug_id, ldesc.who, ldesc.bug_when, ldesc.thetext
FROM products prod
INNER JOIN components comp ON comp.product_id = prod.id
INNER JOIN bugs bug ON bug.component_id = comp.id
INNER JOIN longdescs ldesc ON ldesc.bug_id = bug.bug_id
WHERE prod.name = 'Mylyn'
AND comp.name = 'Core'
AND bug.bug_id = 120499 --100629
ORDER BY bug.bug_id, bug_when


-- As for votes and attachments: they don't have a "when" field, so we cannot
-- perform process mining on them
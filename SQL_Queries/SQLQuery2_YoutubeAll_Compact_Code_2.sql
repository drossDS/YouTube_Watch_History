/* ********** DAN'S YOUTUBE WATCH HISOTRY FOR 10+ YEARS IN SQL! ********************/

/* DATA WAS EXPORTED FROM GOOGLE "TAKEOUT" AS A JSON FILE (Circa March 2022)*/


-------------------------------------------------------------------------------------------------------------------

--1 - READ JASON DATA INTO A SQL DATABASE TABLE

Declare @JSON varchar(max)
SELECT @JSON=BulkColumn
FROM OPENROWSET (BULK 'C:\Users\Dan\Documents\Data Science Portfolio\SQL\Takeout-JSON\YouTube and YouTube Music\history\watch-history.json', SINGLE_CLOB) import
SELECT * INTO YouTubeWatchHistory
FROM OPENJSON (@JSON)
WITH ( 
	Vid_Title NVARCHAR(500) '$.title',
	Time NVARCHAR(500) '$.time',
	Channel NVARCHAR(500) '$.subtitles[0].name',
	Vid_URL NVARCHAR(1000) '$.titleUrl',
	Ch_URL NVARCHAR(1000) '$.subtitles[0].url'
	)

--1.1 - EXAMINE DATA BRIEFLY BEFORE CLEANING

--FIND THE MOST WATCHED VIDEOS
select Vid_Title, Count(Vid_Title), Vid_URL
from YouTubeWatchHistory
Group BY Vid_Title, Vid_URL
Order BY Count(Vid_Title) DESC

--FIND THE MOST WATCHED VIDEOS AND EXTRACT THE VIDEO IDs
select Vid_Title, Count(Vid_Title) AS Vid_Count, Vid_URL, right(Vid_URL, (len(Vid_URL) - CHARINDEX('=', Vid_URL))) AS Vid_Id
from YouTubeWatchHistory
Group BY Vid_Title, Vid_URL, right(Vid_URL, (len(Vid_URL) - CHARINDEX('=', Vid_URL)))
Order BY Count(Vid_Title) DESC

--FIND MOST WATCHED CHANNELS
Select Channel, COUNT(Channel) as ChVidCount, Ch_URL as ChannelURL
From YouTubeWatchHistory
GROUP BY Channel, Ch_URL
ORDER BY COUNT(Channel) DESC

--1.2 SELECT AND INVESTIGATE ALL VIDEOS WITH NULL CHANNELS, BUT NOT NULL VIDEO TITLES
select *
from YouTubeWatchHistory
where Channel IS NULL AND Vid_Title NOT LIKE 'Watched a video that has been removed'

	/* NOTE:  Channels with "https:..." in their title appear to have been taken down.  Assume that these were ads or something.
	Determine if any other Null channel videos have titles without "https..." and investigate */

select *
from YouTubeWatchHistory
where Channel IS NULL AND Vid_Title NOT LIKE 'Watched a video that has been removed' AND Vid_Title not like '%http%'

	/* NOTE:  Examining the JSON shows that there is a "details" section for these that says "From Google Ads".  It would be
	good to add this to the intial data imported from the JSON and see if this is only for the videos queried here, or
	if there are other videos like this which should be removed.  In principle, ads should not be considered part of
	watch history */

--1.2.1 ADD THE DETAILS DATA TO THE CURRENT TABLE

	/* NOTE:  For practice, a new table was made with just the video ID and the corresponding details.  This table is then left joined
	to the original table to add the details column.  Normally, one would go back and add the details column when the table was originally
	created, but in this case, it was an opportunity to peform a join and add a column to a table.*/

--MAKE A TABLE WITH THE DETAILS DATA IMPORTED FROM THE JSON FILE
DECLARE @JSON_D varchar(max)
SELECT @JSON_D=BulkColumn
FROM OPENROWSET (BULK 'C:\Users\Dan\Documents\Data Science Portfolio\SQL\Takeout-JSON\YouTube and YouTube Music\history\watch-history.json', SINGLE_CLOB) import
SELECT * INTO Details
FROM OPENJSON (@JSON_D)
WITH (
	Vid_Title NVARCHAR(500) '$.title',
	Details NVARCHAR(100) '$.details[0].name'
	)

--ADD A DETAILS COLUMN TO THE MAIN TABLE
ALTER TABLE YouTubeWatchHistory ADD Details NVARCHAR(500)

--UPDATE THE DETAILS COLUMN IN THE MAIN TABLE WITH THE DETAILS FROM THE DETAILS TABLE
update YouTubeWatchHistory
	set YouTubeWatchHistory.Details = Details.Details
	FROM YouTubeWatchHistory LEFT JOIN Details ON YouTubeWatchHistory.Vid_Title = Details.Vid_Title

--VIEW THE DATA TO SEE WHICH VIDEOS HAVE DETAILS DATA AND WHAT THE FIELD CONTAINS
SELECT *
FROM YouTubeWatchHistory
where Details IS NOT NULL
	
	/*NOTE: Only 21 videos were present with a non-null value for details, and all of those were "From Google Ads"
	Thus, there are no other important details categories, and it's safe to assume that all of these videos
	can be neglected going forward as they are all adds.*/


-----------------------------------------------------------------------------------------------------------------------------------------------------

--2 - CLEAN DATA AND CREATE NEW TABLE
select * into YTWH
From YouTubeWatchHistory
where Channel IS NOT NULL AND Vid_Title NOT LIKE 'Watched a video that has been removed' AND Vid_Title not like '%http%' AND Details is NUll

Select * From YTWH


------------------------------------------------------------------------------------------------------------------------------------------------------

--3 - PERFORM BASIC EXPLORATORY ANALYSIS ON CLEANED DATA

--DETERMINE THE MOST WATCHED VIDEOS, SORT BY COUNT
select Vid_Title, Channel, Count(Vid_Title), Vid_URL
from YTWH
Group BY Vid_Title, Channel, Vid_URL
Order BY Count(Vid_Title) DESC

--DETERMINE THE MOST WATCHED CHANNELS, SORT BY (VIEW) COUNT
SELECT Channel, COUNT(Channel) as Ch_Count, Ch_URL
from YTWH
Group By Channel, Ch_URL
Order by Count (Channel) DESC

--DETERMINE THE CHANNELS WITH THE MOST INDIVIDUAL VIDEOS VIEWED
	--FIRST, CREATE A NEW TABLE FROM THE MOST WATCHED VIDEOS QUERY TO OBTAIN A LIST OF DISTINCT VIDEOS
select Vid_Title, Channel, Count(Vid_Title) NoVidViews, Vid_URL 
INTO ChPopViews
from YTWH
Group BY Vid_Title, Channel, Vid_URL

select * from ChPopViews
Order by NoVidViews DESC

	--SECOND, QUERY THE NEW TABLE TO OBTAIN THE NUMBER OF INDIVIDUAL VIDEOS WATCHED FROM EACH CHANNEL
select Channel, Count(Vid_Title) VidCount
from ChPopViews
Group By Channel
Order by VidCount DESC


--------------------------------------------------------------------------------------------------------------------------------------------------

-- 4 - PERFORM TIME REFORMATTING, FIND DAYS OF WEEK, BREAK OUT TIME (USE HOURS FOR NOW) - MAKE NEW TABLE 'YTWH2'
select Vid_Title, Channel, CONVERT(DATETIME2(0), (CONVERT(DATETIME2(0), Time)  AT TIME ZONE 'UTC' AT TIME ZONE 'Eastern Standard Time')) AS Date_Time,
DATENAME(WEEKDAY, (CONVERT(DATETIME2(0), Time)  AT TIME ZONE 'UTC' AT TIME ZONE 'Eastern Standard Time')) AS Weekday,
DATEPART(HOUR, (CONVERT(DATETIME2(0), Time)  AT TIME ZONE 'UTC' AT TIME ZONE 'Eastern Standard Time')) AS Hour, Vid_URL, Ch_URL
into YTWH2
from YTWH

select Vid_Title, Count(Vid_Title) Watch_Count, MAX(Vid_URL) Video_URL, max(right(Vid_URL, (len(Vid_URL) - CHARINDEX('=', Vid_URL)))) AS Vid_Id
from YTWH2
Group BY Vid_Title
Order BY Count(Vid_Title) DESC

 -- 4.1 - CREATE YET ANOTHER TABLE WITH COMMAS REMOVED FROM VID_TITLE TO EXPORT AS A CSV WITHOUT ERRORS
SELECT REPLACE(Vid_Title, ',', '') as Vid_Title_Clean, REPLACE(Channel, ',', '') as Channel_Clean, *
INTO Clean_Final_Table
from YTWH2
ALTER TABLE Clean_Final_Table
DROP COLUMN Vid_Title, Channel

-- VIEW CLEAN_FINAL_TABLE TO VERIFY
SELECT * FROM Clean_Final_Table
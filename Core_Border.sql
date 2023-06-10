--The first part of this query will create a temporary table with all cells and their neighbors

select c1.*

-- teste - 1 means that the neighboring cell is in the direction of the main antenna lobe, which in this case we define as 65°. And 0 means outside the main lobe.

, (case when c1.az_ang < 32.499 then 1 else (case when c1.az_ang > 327.499 then 1 else 0 end) end)  teste 
into #lixo1 ---saving results in a temporary table.
from
(

--- to identify all source and target cells we create two exactly the same queries (a1 and a2) 
--where a1 will be called source (src) and a2 will be target (tgt) 

select b1.*
, (case when b1.Azimute_src - b1.Angulo < 0 then (b1.Azimute_src - b1.Angulo + 360) else (case when b1.Azimute_src - b1.Angulo > 360
then b1.Azimute_src - b1.Angulo - 360 else b1.Azimute_src - b1.Angulo end)end) az_ang
from
(
select a1.site_src, a1.sector_src, a1.Long_src, a1.Lat_src, a1.earfcndl_src as uarfcndl_src, a1.PCI PCI_src
 , a2.site_tgt, a2.sector_tgt, a2.Long_tgt, a2.Lat_tgt, a2.earfcndl_tgt as uarfcndl_tgt, a2.PCI PCI_tgt
---Distance calculation
, (Round(6371*Acos(Cos(3.1416*(90-a2.Lat_tgt)/180)*Cos((90-a1.Lat_src)*3.1416/180)+Sin((90-a2.Lat_tgt)*3.1416/180)*Sin((90-a1.Lat_src)*3.1416/180)*Cos((a1.Long_src-a2.Long_tgt)*3.1416/180)),2)) Distancia_Km

, (cast((Degrees(ATN2(SIN(RADIANS(a2.Long_tgt - a1.Long_src)) * COS(RADIANS(a2.Lat_tgt)), COS(RADIANS(a1.Lat_src)) *
SIN(RADIANS(a2.Lat_tgt)) - SIN(RADIANS(a1.Lat_src)) * COS(RADIANS(a2.Lat_tgt)) * COS(RADIANS(a2.Long_tgt - a1.Long_src))))+ 360) as decimal (18,12)) %360) Angulo
, a1.Azimute_src, a1.Altura_src, a1.Cobertura_src
, a2.Azimute_tgt, a2.Altura_tgt, a2.Cobertura_tgt 

from
(
select z2.*, z1.PCI, z1.earfcndl as earfcndl_src
from
(
select UF, eNB, ---UF = State
CELL,  cellId, earfcndl, tac, administrativeState
,  PCI
 from dbname.dbo.EUtranCell a ---Newtork Parameters table
 
 ) z1
 inner join
 (
select  SiteId as site_src, Sector as sector_src , LONGITUDE as Long_src, LATITUDE as Lat_src
 , Height as Altura_src, SiteType as Cobertura_src, Azimuth as Azimute_src 
 from dbname.dbo.physical_parameters --- eNB physical parameters (Lat, Long, Azimuth, Height, SiteType - Indoor or Outdoor)

) z2
on
z1.eNB = z2.site_src
and z1.CELL = z2.sector_src
) a1
,
(
select z2.*, z1.PCI, z1.earfcndl as earfcndl_tgt
from
(
select UF, eNB, 
CELL,  cellId, earfcndl, tac, administrativeState
, PCI
 from dbname.dbo.EUtranCell a ---Newtork Parameters table
 ) z1
 inner join
 (
select  SiteId as site_tgt, Sector as sector_tgt , LONGITUDE as Long_tgt, LATITUDE as Lat_tgt
 , Height as Altura_tgt, SiteType as Cobertura_tgt, Azimuth as Azimute_tgt 
 from dbname.dbo.physical_parameters

) z2
on
z1.eNB = z2.site_tgt
and z1.CELL = z2.sector_tgt
) a2
where
a1.Lat_src+a1.Long_src <> a2.Lat_tgt+a2.Long_tgt ---source and target cells cannot be at the same location
---Looking for neighbors up to 150km away. We can reduce the value of the distance to decrease the execution time of the query 
and (Round(6371*Acos(Cos(3.1416*(90-a2.Lat_tgt)/180)*Cos((90-a1.Lat_src)*3.1416/180)+Sin((90-a2.Lat_tgt)*3.1416/180)*
Sin((90-a1.Lat_src)*3.1416/180)*Cos((a1.Long_src-a2.Long_tgt)*3.1416/180)),2)) < 150 
---and a1.uarfcndl_src = a2.uarfcndl_tgt 
--and a1.PCI = a2.PCI
) b1
) c1


GO

-----------------------------------------------------------------------------------


drop table dbname.dbo.core_border_65 --- this command line can only be used if you already have this table created in your database, otherwise just comment (--) this line.

GO

-----------------------------------------------------------------------------------

-- The second query (below) will use the table of logical parameters "Eutrancell" and join with the virtual table "lixo1" to verify the list of cells and their closest neighbors (RANK=1).
-- If there is no neighbor within the distance defined in query 1 (150km), then the neighbor data will be blank
select candy.* into 
dbname.dbo.core_border_65
from
(
select leo.UF, leo.eNB site_src, leo.CELL sector_src,	lale.Long_src,	lale.Lat_src,	leo.earfcndl as uarfcndl_src,	lale.PCI_src,	
lale.site_tgt,	lale.sector_tgt,	lale.Long_tgt,	lale.Lat_tgt,	lale.uarfcndl_tgt,	lale.PCI_tgt,	lale.Distancia_Km,	lale.Angulo,	
lale.Azimute_src,	lale.Altura_src,	lale.Cobertura_src,	lale.Azimute_tgt,	lale.Altura_tgt,	lale.Cobertura_tgt,	lale.az_ang
, leo.cellRange, leo.crsGain
-- The "TYPE" column defines core and border where we can adjust the distance, which in this case is 5km.
, case when ISNULL(lale.Distancia_Km,0) between 0.0000000001 and 5 then 'CORE' else 'BORDER' end 'TYPE'
from
(
select UF, eNB, 
CELL,  cellId, earfcndl, dlChannelBandwidth, tac, administrativeState
, PCI
, crsGain, latitude, longitude, cellRange
 from dbname.dbo.EUtranCell
  ) leo

 left outer join 
(
select b.*
from
(
select a.* 
-- RANK - will rank neighbors by distance, where 1 is closest.
, ROW_NUMBER() OVER(PARTITION BY a.site_src , a.sector_src ORDER BY(a.Distancia_Km) ASC) RANK
from #lixo1 a
where 
teste = 1
) b
where RANK = 1
) lale
on
CONCAT(leo.CELL,'_',leo.UF) = CONCAT(lale.sector_src,RIGHT(site_src,3)) 
) candy


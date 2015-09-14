library(V8)
library(dplyr)
library(leaflet)
library(htmltools)

ctx <- new_context()
# will be better handled with require
ctx$source("./lib/topojson.js")
ctx$source("./bower_components/d3/d3.min.js")
ctx$source("cartogram.js")

# add the states data
ctx$eval(sprintf(
  'var topo = %s'
  ,paste0(
    readLines("./data/us-states.topojson")
    ,collapse = " "
  )
))

# make sure states data is there
ctx$get('topo')

# use the sample data from the d3-cartogram example
df <- read.csv(
  "./data/nst_2011.csv"
  ,stringsAsFactors = FALSE
)
# assign the sample data as dataById in V8
df %>%
  filter( STATE > 0 ) %>%
  select( STATE, NAME, CENSUS2010POP ) %>%
  group_by( NAME ) %>%
  do(
    values = tbl_df( . )
  ) %>%
  {
    ctx$assign(
      "dataById"
      ,.
    )
  }

# set up the cartogram
ctx$eval(
'
var proj = d3.geo.albersUsa();

var scale = d3.scale.linear();
scale.domain(d3.extent(dataById,function(d){return +d.values[0].CENSUS2010POP}));
scale.range([1,1000]);

var carto = d3.cartogram()
  .projection(proj)
  .properties(function(d) {
    // little different here in that
    // use filter since dplyr/jsonlite gives different dataById format
    //  and we will get .values
    return dataById.filter(
        function(dd){
          return dd.NAME == d.id;
        }
      )[0].values[0];
  })
  .value(function(d) {
    console.log(d);
    return scale(+d.properties.CENSUS2010POP)
  });
'
)

# do the transform
ctx$eval(
'
var features = carto(topo, topo.objects.states).features;
'
)

# get the path attributes of transformed for svg
paths <- ctx$get(
  "features.map(function(ftr){return carto.path(ftr)})"
)

# make our svg
browsable(
  tag("svg"
    ,list(
      style = "height:100%;width:100%;"
      ,viewBox = '0 0 1000 700'
      ,tag("g"
        ,c(
          #transform = 'translate(0,100) scale(1,-1)'
          lapply(
            paths
            ,function(path){
              tag("path"
                ,c(
                  "d" = path
                  ,style = "fill:rgb(181,181,181);stroke:black;"
                )
              )
            }
          )
        )
      )
  ))
)
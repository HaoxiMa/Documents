library(leaflet)
library(dplyr)
library(RCurl)
library(rgdal)
library(htmltools)
library(shiny)
library(shinydashboard)

#=======Data preprocessing========
case.data <- getURL('https://raw.githubusercontent.com/CSSEGISandData/COVID-19/master/csse_covid_19_data/csse_covid_19_time_series/time_series_covid19_confirmed_US.csv')
raw_case <- read.csv(text = case.data,header=T)
death.data<-getURL("https://raw.githubusercontent.com/CSSEGISandData/COVID-19/master/csse_covid_19_data/csse_covid_19_time_series/time_series_covid19_deaths_US.csv")
raw_death<-read.csv(text=death.data,header=T)

case<-raw_case %>% select(c(7,(ncol(raw_case)-1),ncol(raw_case))) 
case$daily.newcase<-case[,3]-case[,2]
case<- case %>% rename(States=Province_State) %>% group_by(States) %>%
    summarise(new.case=sum(daily.newcase))

death<-raw_death %>% select(c(7,(ncol(raw_death)-1),ncol(raw_death))) 
death$daily.newdeath<-death[,3]-death[,2]
death<- death %>% rename(States=Province_State) %>% group_by(States) %>%
    summarise(new.death=sum(daily.newdeath))

final_data<-merge(case,death)

#import shapefile
states.shape<-readOGR("../cb_2018_us_state_500k/cb_2018_us_state_500k.shp")

#Align
is.element(final_data$States,states.shape$NAME)
final_data<-final_data[-c(10,14),]
final_data$States<-factor(final_data$States)
levels(final_data$States)[38]<-"Commonwealth of the Northern Mariana Islands"
levels(final_data$States)[51]<-"United States Virgin Islands"
final_data<-final_data[order(match(final_data$States,states.shape$NAME)),]

#color pallet
bins<-c(0,10,100,500,2500,5000,10000,15000,Inf)
pal<-colorBin("RdYlBu",domain = c(0,1),bins = bins)

#============R Shiny=========

ui <- dashboardPage(
    skin = "blue",
    dashboardHeader(title = "COVID-19 Daily Index"),
    dashboardSidebar(
        radioButtons(inputId = "class",
                     label = "Outcome",
                     choices = c("New Cases"="new.case","New Death"="new.death"),
                     selected = "new.case")
    ),
    dashboardBody(
        leafletOutput(outputId = "Dmap")
    )
)

server <- function(input, output) {
    labels<-reactive({
        paste("<p>",final_data$States,"</p>",
              "<p>","Daily index: ",final_data[,input$class],"</p>",sep="")
    })

    output$Dmap <- renderLeaflet(
        leaflet() %>% 
            addProviderTiles(provider = providers$Stamen.Toner) %>%
            setView(lng = -96,lat = 37.8,zoom = 3.5) %>%
            addPolygons(data = states.shape, 
                        weight = 1, 
                        color = "white",
                        fillOpacity = 0.5, 
                        fillColor = pal(final_data[,input$class]),
                        label = lapply(labels(),HTML),
                        highlightOptions = highlightOptions(
                            weight = 5,
                            color = "#666666",
                            fillOpacity = 0.7,
                            bringToFront = TRUE
                        )) 
    )
}

# Run the application 
shinyApp(ui = ui, server = server)

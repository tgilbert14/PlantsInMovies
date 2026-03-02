
library(shiny)
library(shinycssloaders)
library(shinythemes)
library(shinyjs)
library(shinydashboard)
library(tidyverse)
library(circlize)
library(plotly)

plant_data <- read_csv("www/my_plant_data.csv")

states_list <- c("Arizona","Alabama","Alaska","Arkansas","California","Colorado",
            "Connecticut","Delaware","Florida","Georgia","Hawaii","Idaho",
            "Illinois","Indiana","Iowa","Kansas","Kentucky","Louisiana",
            "Maine","Maryland","Massachusetts","Michigan","Minnesota",
            "Mississippi","Missouri","Montana","Nebraska","Nevada",
            "New Hampshire","New Jersey","New Mexico","New York",
            "North Carolina","North Dakota","Ohio","Oklahoma","Oregon",
            "Pennsylvania","Rhode Island","South Carolina","South Dakota",
            "Tennessee","Texas","Utah","Vermont","Virginia","Washington",
            "West Virginia","Wisconsin","Wyoming")

# Define UI for application that draws a histogram
ui <- fluidPage(
  shinyjs::useShinyjs(),
  #theme = shinytheme("slate"),
  theme = shinytheme("cyborg"),
  
    # Application title
    titlePanel(div(style = "color: cyan; font-size: 32px;",
      HTML("<strong>Which State's Flora Matches each Movie World Best?</strong>"))),
  
    # Sidebar with a slider input for number of bins 
    sidebarLayout(
        sidebarPanel(width = 3, 
                     
                     box(
                       div(style = "color: orange; font-size: 16px;",id="select",
                       HTML("Select <strong>state(s)</strong> to create a chord plot
                       that shows how many unique plant species they share with each 
                       movie-themed biome!")),
                       
                       title = NULL, status = "primary", solidHeader = TRUE, width = NULL),
                       br(),
                     box(
                       title = NULL, status = "warning", solidHeader = TRUE, width = NULL,
          selectizeInput("state", label = NULL,
                         choices = c(states_list), selected = FALSE, multiple = TRUE),

          
          selectizeInput("state_2", label = "Add other states",
                         choices = c(states_list), selected = FALSE, multiple = TRUE),
          actionButton(
            inputId = "click_state",
            label = "Create/Refresh",
            icon = icon("refresh"),
            width = "100%", 
            class = "btn-warning"
          )
        ),
        br(),
        div(style = "color: #0072B2; font-size: 12px;", id="start",
        HTML("<p><em>Species were pulled from the USDA plant database and filtered to 
        include only those whose families matched the movie biome themes.</em></p>
        <p><strong>Dune (<em>Arrakis</em>)</strong> includes plant families associated 
        with succulents, desert plants, grasses and drought-adapted species.</p>
        <p><strong>Lord of the Rings (<em>Middle-earth</em>)</strong> includes cool 
        forest and alpine plant families.</p><p>
        <strong>Jurassic Park (<em>Isla Nublar</em>)</strong> includes families 
        that represent ancient groups such as ferns, conifers, and horsetails.</p><p>
        <strong>The thinkness of each cord represents the the number of species 
        from each family group found in each state.</strong>
        <p><em>Please contact tsgilbert@arizona.edu with questions of feedback!</em></p>")
        ),
        #br(),
        ## more info button
        actionButton(
          inputId = "more_info",
          label = "More Info",
          icon = icon("info-circle"),
          width = "100%",
          class = "btn-info"
        )),

        mainPanel(

          ## add spacing on top
          br(),
          verbatimTextOutput("state_text", placeholder = F),

          fluidRow(
            column(width = 4,
                   plotlyOutput("stat_arr", height = "140px",
                                inline = TRUE, width = "90%")),
            column(width = 4,
                   plotlyOutput("stat_lotr", height = "140px",
                                inline = TRUE, width = "90%")),
            column(width = 4,
                   plotlyOutput("stat_isla", height = "140px",
                                inline = TRUE, width = "90%"))),
          
          div(style = "color: #0072B2; font-size: 14px;", id="guauge_info",
              HTML("Percents represent portions of the newest selected state divided 
              amoungst movie theme biomes and other states selected. <em>For example,
              Arizona in 51.1% LOTR when selected alone, but when California is added
              Arizona drops to 32.9% LOTR because it shares species with California
              as well.</em> The higher the %, the more similar the flora of the state 
              is to the movie world!")),
          # end of row
          br(),
            
            shinycssloaders::withSpinner(plotOutput("distPlot", height = "400px"),type = 6,
                                         size = 4, color = "#0072B2",
                                         color.background = "#009E73")
          )
    )
)


server <- function(input, output) {
  
  
  shinyjs::hide("state_2")
  shinyjs::hide("start")
  shinyjs::hide("guauge_info")
  shinyjs::hide("more_info")

  observeEvent(input$click_state, {
    shinyjs::hide("select")
    shinyjs::show("guauge_info")
    shinyjs::show("more_info")
    shinyjs::show("start")
  })
  
  observeEvent(input$more_info, {
    showModal(modalDialog(
      title = HTML("<strong>Species Family Breakdown</strong>"),
      HTML('<p><strong>The Isla Nublar (Jurracic Park)</strong> families are focused on ferns, 
      conifers, horsetails, and ancient groups. The families included are:
      "Araucariaceae", "Aspleniaceae", "Blechnaceae", "Cupressaceae", "Cyatheaceae", 
      "Cycadaceae", "Dennstaedtiaceae", "Dryopteridaceae", "Equisetaceae", 
      "Ginkgoaceae", "Isoetaceae", "Marattiaceae", "Ophioglossaceae", "Osmundaceae", 
      "Pinaceae", "Podocarpaceae", "Polypodiaceae", "Psilotaceae", "Pteridaceae", 
      "Selaginellaceae", "Thelypteridaceae" and "Zamiaceae"</p><p>
      <strong>The Arrakis (Dune)</strong> families are focused on succulents, desert plants, 
      grasses, and weeds. The families included are: "Agavaceae", "Aizoaceae", 
      "Amaranthaceae", "Anacardiaceae", "Asparagaceae", "Brassicaceae", "Burseraceae", 
      "Cactaceae", "Fouquieriaceae", "Frankeniaceae", "Poaceae", "Polygonaceae", 
      "Tamaricaceae" and "Zygophyllaceae"</p><p>
      <strong>The Middle-earth (LOTR)</strong> families are focused on cool forests and alpine plants. The
      families included are: "Apiaceae", "Araliaceae", "Asteraceae", "Betulaceae",
      "Cornaceae", "Ericaceae", "Fagaceae", "Gentianaceae", "Hydrangeaceae", "Juglandaceae", 
      "Primulaceae", "Ranunculaceae", "Rosaceae", "Salicaceae" and "Saxifragaceae"</p>'),
      easyClose = TRUE,
      footer = NULL
    ))
  })

  data <- reactive({
    req(input$state, input$click_state)
    
    picked_state <- input$state
    
    if (length(input$state_2) > 0) {
      picked_state <- c(picked_state, input$state_2)
    }
    
    #View(plant_data)
    
    ## updated versions trying to include as much families as possible -->
    
    ## ferns, conifers, horsetails, and ancient groups -->
    jurrasicP <- c("Araucariaceae","Aspleniaceae","Blechnaceae","Cupressaceae",
                   "Cyatheaceae","Cycadaceae","Dennstaedtiaceae","Dryopteridaceae",
                   "Equisetaceae","Ginkgoaceae","Isoetaceae","Marattiaceae",
                   "Ophioglossaceae","Osmundaceae","Pinaceae","Podocarpaceae",
                   "Polypodiaceae","Psilotaceae","Pteridaceae","Selaginellaceae",
                   "Thelypteridaceae","Zamiaceae")
    ## succulents, desert plants, grasses, weeds -->
    dune <- c("Agavaceae","Aizoaceae","Amaranthaceae","Anacardiaceae","Asparagaceae",
              "Brassicaceae","Burseraceae","Cactaceae","Fouquieriaceae",
              "Frankeniaceae","Poaceae","Polygonaceae","Tamaricaceae","Zygophyllaceae")
    ## cool forests and alpine plants -->
    LOTR <- c("Apiaceae","Araliaceae","Asteraceae","Betulaceae","Cornaceae",
              "Ericaceae","Fagaceae","Gentianaceae","Hydrangeaceae","Juglandaceae",
              "Primulaceae","Ranunculaceae","Rosaceae","Salicaceae","Saxifragaceae")
    
    ## put plants in movie groups - get rid of "Other"
    in_groups <- plant_data %>% 
      mutate(Movie = case_when(
        Family %in% jurrasicP ~ "Isla Nublar",
        Family %in% dune ~ "Arrakis",
        Family %in% LOTR ~ "Middle-earth",
        TRUE ~ "Other"
      )) %>% 
      group_by(Movie, State) %>% 
      tally() %>% 
      filter(Movie != "Other") %>%
      arrange(desc(n))
    
    ## have to count what num species each state shares!
    ## mot doing families because could be wayyyyy different!
    
    x=1 # for anchor state (Movie column)

    
    while (x <= length(picked_state) && length(picked_state) > 1) {
      
      ## when more than one state
      i=1 # for every other species to compare to
      
      ## for all states
      while(i <= length(picked_state)) {
        
        ## families in state 
        state_fams <- plant_data %>% 
          filter(State == picked_state[x]) %>% 
          select(symbol)
        
        ## families all the other states selected
        ## unless last entry
        if (i == length(picked_state)) {
          # skip if last..
          # other state?
        } else{
          state_fams_comp <- plant_data %>% 
            filter(State == picked_state[i+1]) %>% 
            select(symbol)
          num_shared_sp <- length(intersect(state_fams$symbol, state_fams_comp$symbol))
          ## add to in_groups
          in_states <- data.frame(Movie = picked_state[x], State = picked_state[i+1], n = num_shared_sp)
          in_groups <- rbind(in_groups, in_states)
        }
        
        i=i+1

      }
      ## go to next anchor species (for movie column)
      x=x+1
    }

    in_groups <- in_groups %>% 
      filter(State %in% c(picked_state)) %>% 
      filter(Movie != State)

    clean_data <- in_groups %>% 
      mutate(Movie_2 = ifelse(Movie %in% states_list, State, Movie)) %>% 
      mutate(State_2 = ifelse(Movie %in% states_list, Movie, State)) %>% 
      select(Movie = Movie_2, State = State_2, n)

    # rows where both nodes are in the selected states
    rows_to_mirror <- clean_data %>%
      filter(State %in% states_list & Movie %in% states_list) %>%
      arrange(n)
    
    mirr_data <- rows_to_mirror
    ## switch movie and state columns
    mirr_data$State <- rows_to_mirror$Movie
    mirr_data$Movie <- rows_to_mirror$State
    
    clean_data <- bind_rows(clean_data, mirr_data)
    
    ## get rid of duplicates
    in_groups_stateComp <- unique(clean_data)
    
    in_groups_stateComp
    
  }) ## end of reactive data
  
  
  ## update guages -->
  observe({
    
    output$state_text <- renderText({
      
      req(input$state)
      my_data <- data()
      
      ## track 1st state, then track newest state
      if (length(input$state_2) > 0) {
        current_state <- c(input$state, input$state_2)
      } else {
        current_state <- input$state
      }
      
      newest_state <- current_state[length(current_state)]
      paste0(newest_state," is...")
    })
    
    output$stat_arr <- renderPlotly({
      
      req(input$state)
      my_data <- data()
      
      ## track 1st state, then track newest state
      if (length(input$state_2) > 0) {
        current_state <- c(input$state, input$state_2)
      } else {
        current_state <- input$state
      }
      
      newest_state <- current_state[length(current_state)]
      
      percents <- my_data %>% 
        group_by(State) %>% 
        mutate(perc = round(n/sum(n)*100,1))
      
      my_data_perc <- percents %>% 
        filter(State == newest_state) %>% 
        filter(Movie == "Arrakis")
      
      per <- my_data_perc$perc
      st <- my_data_perc$State

      ## set color based on percent
      my_col <- c("#0B04E0", "#333EAD", "#5C797A", "#84B346", "#ACED13")
      col <- ifelse(per > 0 & per < 15, my_col[5],
                    ifelse(per >= 15 & per < 35, my_col[4],
                           ifelse(per >= 35 & per < 55, my_col[3],
                                  ifelse(per >= 55 & per < 80, my_col[2], my_col[1]))))
      
      fig <- plot_ly(
        domain = list(x = c(0, 1), y = c(0, 1)),
        value = per,
        type = "indicator",
        mode = "gauge+number",
        gauge = list(
          axis = list(range = list(0, 100), tickwidth = 1, tickcolor = "orange",
                      showticklabels = FALSE),
          bar = list(color = col),
          steps = list(
            list(range = c(0, 25), color = "gray40"),
            list(range = c(75, 100), color = "gray40")
          )
        ),
        number = list(suffix = "%")
      )
      
      fig <- fig %>%
        layout(
          title = HTML('<span style="color: orange; font-size: 14px;"><em>Dune</em></span>'),
          margin = list(l = 20, r = 30),
          paper_bgcolor ="black",
          font = list(color = "orange", family = "Arial", size = 10)
        )
      fig
    })
    
    output$stat_lotr <- renderPlotly({
      
      req(input$state)
      my_data <- data()
      
      ## track 1st state, then track newest state
      if (length(input$state_2) > 0) {
        current_state <- c(input$state, input$state_2)
      } else {
        current_state <- input$state
      }
      
      newest_state <- current_state[length(current_state)]
      
      percents <- my_data %>% 
        group_by(State) %>% 
        mutate(perc = round(n/sum(n)*100,1))
      
      my_data_perc <- percents %>% 
        filter(State == newest_state) %>% 
        filter(Movie == "Middle-earth")
      
      per <- my_data_perc$perc
      st <- my_data_perc$State
      
      ## set color based on percent
      my_col <- c("#0B04E0", "#333EAD", "#5C797A", "#84B346", "#ACED13")
      col <- ifelse(per > 0 & per < 15, my_col[5],
                    ifelse(per >= 15 & per < 35, my_col[4],
                           ifelse(per >= 35 & per < 55, my_col[3],
                                  ifelse(per >= 55 & per < 80, my_col[2], my_col[1]))))
      
      fig <- plot_ly(
        domain = list(x = c(0, 1), y = c(0, 1)),
        value = per,
        type = "indicator",
        mode = "gauge+number",
        gauge = list(
          axis = list(range = list(0, 100), tickwidth = 1, tickcolor = "orange",
                      showticklabels = FALSE),
          bar = list(color = col),
          steps = list(
            list(range = c(0, 25), color = "gray40"),
            list(range = c(75, 100), color = "gray40")
          )
        ),
        number = list(suffix = "%")
      )
      
      fig <- fig %>%
        layout(
          title = HTML('<span style="color: orange; font-size: 14px;"><em>LOTR</em></span>'),
          margin = list(l = 20, r = 30),
          paper_bgcolor = "black",
          font = list(color = "orange", family = "Arial")
        )
      fig
    })
    
    output$stat_isla <- renderPlotly({
      
      req(input$state)
      my_data <- data()

      ## track 1st state, then track newest state
      if (length(input$state_2) > 0) {
        current_state <- c(input$state, input$state_2)
      } else {
        current_state <- input$state
      }
      
      newest_state <- current_state[length(current_state)]
      
      percents <- my_data %>% 
        group_by(State) %>% 
        mutate(perc = round(n/sum(n)*100,1))
      
      # percents <<- percents
      # my_data <<- my_data
      # stop()
      # View(my_data)
      # View(percents)
      
      my_data_perc <- percents %>% 
        filter(State == newest_state) %>% 
        filter(Movie == "Isla Nublar")
      
      per <- my_data_perc$perc
      st <- my_data_perc$State
      
      ## set color based on percent
      my_col <- c("#0B04E0", "#333EAD", "#5C797A", "#84B346", "#ACED13")
      col <- ifelse(per > 0 & per < 15, my_col[5],
                    ifelse(per >= 15 & per < 35, my_col[4],
                           ifelse(per >= 35 & per < 55, my_col[3],
                                  ifelse(per >= 55 & per < 80, my_col[2], my_col[1]))))
      fig <- plot_ly(
        domain = list(x = c(0, 1), y = c(0, 1)),
        value = per,
        type = "indicator",
        mode = "gauge+number",
        gauge = list(
          axis = list(range = list(0, 100), tickwidth = 1, tickcolor = "orange",
                      showticklabels = FALSE),
          bar = list(color = col),
          steps = list(
            list(range = c(0, 25), color = "gray40"),
            list(range = c(75, 100), color = "gray40")
          )
        ),
        number = list(suffix = "%")
      )
      
      fig <- fig %>%
        layout(
          title = HTML('<span style="color: orange; font-size: 14px;"><em>Jurrassic Park</em></span>'),
          margin = list(l = 20, r = 30),
          paper_bgcolor ="black",
          font = list(color = "orange", family = "Arial")
        )
      fig
    })
    
    
    ## render plot in shiny
    output$distPlot <- renderPlot({
      req(input$state, input$click_state)
      
      my_data <- data()
      
      if (nrow(my_data) == 0) {
        return(NULL) # Return NULL if there are no rows to plot
      } else {
        
        ## create a color gradient based on number of cords
        state_colors <- my_data %>% 
          group_by(State) %>% 
          summarise(total_n = sum(n)) %>% 
          arrange(desc(total_n)) %>% 
          mutate(color = colorRampPalette(c("#0B04E0", "#333EAD", "#5C797A", "#84B346", "#ACED13"))(n()))
        
        state_grid_col <- setNames(state_colors$color, state_colors$State)

        par(mai = c(0.4, 0.4, 0.4, 0.4), bg = "gray90", mar = c(0, 0, 0, 0))
        
        chordDiagram(my_data,
                     annotationTrack = c("name", "grid", "axis"),
                     grid.border = "black",
                     grid.col = c("Arrakis" = "black",
                                  "Middle-earth" = "#E67E22",
                                  "Isla Nublar" =  "#1ABC9C",
                                  state_grid_col),
                     preAllocateTracks = .8)

        circos.clear()

      }
      
    }) ## end of plotly output - sanky 
    
  })
  
  

  }

# Run the application 
shinyApp(ui = ui, server = server)

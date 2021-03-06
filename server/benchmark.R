

output$benchmark.learners.sel = renderUI({
  validateLearner(input$learners.sel)
  lrns = learners()
  validateTask(input$create.task, task.data(), data$data, req = TRUE)
  lrn.ids = names(lrns)
  selectInput("benchmark.learners.sel", NULL, choices = lrn.ids,
    multiple = TRUE, selected = lrn.ids)
})

bmr.learners = reactive({
  learners()[input$benchmark.learners.sel]
})

observeEvent(task.type(), {
  if (task.type() != "classif") {
    shinyjs::hide("benchmark.stratification", animType = "slide")
  } else {
    shinyjs::show("benchmark.stratification", anim = TRUE)
  }
})

rdesc.type = reactive(input$benchmark.rdesc.type)

output$benchmark.rdesc.config = renderUI({
  makeResampleDescUI(rdesc.type())
})

output$benchmark.parallel.ui = renderUI({
  list(
    radioButtons("benchmark.parallel", "Parallel benchmarking?", choices = c("Yes", "No"), selected = "No"),
    numericInput("benchmark.parallel.nc", "No. of cores", min = 1L, max = Inf, value = 2L, step = 1L)
  )
})

observeEvent(input$benchmark.parallel, {
  if (input$benchmark.parallel == "No") {
    shinyjs::hide("benchmark.parallel.nc", animType = "fade")
  } else {
    shinyjs::show("benchmark.parallel.nc", anim = TRUE)
  }
})

rdesc = reactive({
  rdesc.type = rdesc.type()
  args = list()
  if (rdesc.type %in% c("CV", "Bootstrap", "Subsample")) {
    args$iters = input$benchmark.iters
  }
  if (rdesc.type == "RepCV") {
    args$reps = input$benchmark.reps
    args$folds = input$benchmark.folds
  }
  if (rdesc.type %in% c("Subsample", "Holdout")) {
    args$split = input$benchmark.split
  }
  args$method = rdesc.type
  do.call("makeResampleDesc", args)
})


measures.bmr.avail = reactive({
  reqAndAssign(task(), "tsk")
  listMatchingMeasures(tsk, bmr.learners())
})

measures.default = reactive({
  reqAndAssign(task.type(), "tsk.type")
  switch(tsk.type, 
    classif = "acc",
    regr = "mse")
})

output$benchmark.measures.sel = renderUI({
  reqAndAssign(measures.bmr.avail(), "ms")
  selectInput("benchmark.measures.sel", "Measures", choices = ms,
    multiple = TRUE, selected = measures.default())
})

measures.bmr = reactive({
  req(input$benchmark.measures.sel)
  listMeasures(task(), create = TRUE)[input$benchmark.measures.sel]
})

bmr = eventReactive(input$benchmark.run, {
  req(learners())
  ms = measures.bmr()
  lrns = bmr.learners()
  rd = rdesc()
  tsk = task()
  reqAndAssign(input$benchmark.parallel, "parallel")
  
  if (parallel == "Yes") {
    parallelStartSocket(cpus = input$benchmark.parallel.nc, level = "mlr.resample")
    withCallingHandlers({
      bmr = benchmark(lrns, tsk, rd, measures = ms, show.info = TRUE)
    },
      message = function(m) {
        shinyjs::html(id = "benchmark.text", html = m$message, add = FALSE)
      }
    )
    parallelStop()
  } else {
    withCallingHandlers({
      bmr = benchmark(lrns, tsk, rd, measures = ms, show.info = TRUE)
    },
      message = function(m) {
        shinyjs::html(id = "benchmark.text", html = m$message, add = FALSE)
      }
    )
  }
  bmr
})

output$benchmark.overview = renderDataTable({
  reqAndAssign(bmr(), "b")
  getBMRAggrPerformances(b, as.df = TRUE)
}, options = list(lengthMenu = c(10, 20), pageLength = 10,
  scrollX = TRUE)
)




##### visualization #####



##### benchmark plots #####

output$bmrplot.measures.sel = renderUI({
  ms = input$benchmark.measures.sel
  selectInput("plot.measures.sel", "Measures", choices = ms,
    selected = measures.default(), width = 200)
})


bmr.plots.out = reactive({
  req(bmr())
  req(measures.bmr())
  req(input$plot.measures.sel)
  plot.type = switch(input$bmrplots.type,
    Beanplots = "violin",
    Boxplots = "box"
  )
  ms = isolate(measures.bmr())[[input$plot.measures.sel]]
  plotBMRBoxplots(bmr(), style = plot.type, measure = ms)
})

output$bmrplots = renderPlot({
  q = bmr.plots.out()
  q
})

bmr.plots.collection = reactiveValues(plot.titles = NULL, bmr.plots = NULL)

observeEvent(bmr.plots.out(), {
  q = bmr.plots.out()
  plot.title = isolate(input$bmrplots.type)
  bmr.plots.collection$plot.titles = unique(c(bmr.plots.collection$plot.titles,
    plot.title))
  bmr.plots.collection$bmr.plots[[plot.title]] = q
})

observeEvent(prediction.plot.out(), {
  q = prediction.plot.out()
  plot.title = isolate(input$prediction.plot.sel)
  prediction.plot.collection$plot.titles = c(prediction.plot.collection$plot.titles, plot.title)
  prediction.plot.collection$pred.plots[[plot.title]] = q
})


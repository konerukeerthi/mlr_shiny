makeModelUI = function(mod, tsk) {
  lrn = mod$learner
  lrn.name = lrn$name
  lrn.par.vals = getLearnerParVals(lrn)
  if (length(lrn.par.vals) > 0) {
    lrn.par.vals = t(data.frame(lrn.par.vals))
    lrn.par.vals = datatable(lrn.par.vals, colnames = c("", ""),
      options = list(paging = FALSE, searching = FALSE,
       bInfo = FALSE, ordering = FALSE))
  } else {
    lrn.par.vals = NULL
  }
  tsk.size = getTaskSize(tsk)
  tsk.nfeats = getTaskNFeats(tsk)
  # mod.box = box(title = "Modeloverview", status = "primary",
  #   solidHeader = TRUE, width = 12,
  #     makeInfoDescription("Learner", lrn.name, 4),
  #     makeInfoDescription("Observations", tsk.size, 4),
  #     makeInfoDescription("Features", tsk.nfeats, 4)
  # )
  mod.box = list(
    fluidRow(
      h3("Model:"),
      h4(lrn.name)
    ),
    fluidRow(
      makeInfoDescription("Observations:", tsk.size, 6, inline = TRUE),
      makeInfoDescription("Features:", tsk.nfeats, 6, inline = TRUE)
    )
  )
  par.vals.box = box(title = "Parameter values", status = "primary",
    solidHeader = TRUE, width = 12,
    # lrn.par.vals
    renderDataTable(lrn.par.vals)
  )
  ui = list(
    mod.box,
    par.vals.box
  )
  return(ui)
}

makeImportPredSideBar = function(type, newdata.type) {
  if (newdata.type == "task") {
    return(NULL)
  } else {
    switch(type, 
      mlr = list(
        selectInput("import.pred.mlr", "Choose toy task", choices = c("iris.task", "bh.task", "sonar.task"))
      ),
      OpenML = list(
        numericInput("import.pred.OpenML", "Choose OpenML Data ID", value = 61L)
      ),
      CSV = list(
        fileInput("import.pred.csv", "Choose CSV File",
          accept = c("text/csv", "text/comma-separated-values,text/plain", ".csv")),
        tags$hr(),
        checkboxInput("import.pred.header", "Header", TRUE),
        selectInput("import.pred.sep", "Separator", selected = ",",
          choices = c(Comma = ",", Semicolon = ";", Tab = "\t")),
        selectInput("import.pred.quote", "Quote", selected = '"',
          choices = c(None = "", "Double Quote" = '"', "Single Quote" = "'"))
      ),
      ARFF = list(
        fileInput("import.pred.arff", "Choose ARFF File",
          accept = c("text/arff", "text/comma-separated-values,text/plain", ".arff"))
      )
    )
  }
}

determinePerformanceStatus = function(worst, best, perf) {
  worst = replaceInfiniteValues(worst)
  best = replaceInfiniteValues(best)
  if (is.na(perf)) {
    status = "primary"
    color = "color:black"
  } else {
    if (best == 0)
      best = 1e-16
    if (perf == 0)
      perf = 1e-16
    perf.rel = abs(perf / best)
    if (perf.rel <= 0.33) {
      status = "danger"
      color = "color:#dd4b39"
    } else {
      if (perf.rel <= 0.66) {
        status = "warning"
        color = "color:#f39c12"
      } else {
        status = "success"
        color = "color:#00a65a"
      }
    }    
  }
  return(list(status = status, color = color))
}

makePerformanceUI = function(measures, performances) {
  ms.ids = names(performances)
  ms.names = extractSubList(measures, "name")
  ms.worst = extractSubList(measures, "worst")
  ms.best = extractSubList(measures, "best")
  # ms.min = extractSubList(measures, "minimize")
  statuses = Map(function(worst, best, perf) {
     determinePerformanceStatus(worst, best, perf)
  }, ms.worst, ms.best, performances)
  
  boxes = Map(function(ms.id, ms.name, perf, worst, best, status) {
    box(title = ms.id, status = status$status, solidHeader = TRUE, width = 3, height = 200,
      fluidRow(
        div(style = "height:50px;", 
          column(width = 12, h5(ms.name), align = "center")
        )
      ),
      fluidRow(
        column(width = 12, div(h4(strong(perf)), style = status$color), align = "center")
      ),
      fluidRow(
        column(width = 12, align = "center",
          makeInfoDescription("worst", worst, width = 6),
          makeInfoDescription("best", best, width = 6)
        )

      )
    )
  }, ms.ids, ms.names, performances, ms.worst, ms.best, statuses)
  return(boxes)
}

makePredictionPlot = function(mod, tsk, tsk.type, plot.type, lrn, fnames, feats,
  preds, ms, resplot.type, vi.method, ind) {
  if (plot.type == "prediction") {
    validate(checkPlotLearnerPrediction(tsk.type, fnames, feats))
    q = plotLearnerPrediction(learner = lrn, features = feats, task = tsk, cv = 0)
  } else if (plot.type == "residuals") {
    req(resplot.type)
    resplot.type = switch(resplot.type,
      scatterplot = "scatterplot",
      "histogram" = "hist")
    q = plotResiduals(preds, type = resplot.type)
  } else if (plot.type == "partial dependency") {
    validate(checkPlotPartialDependency(tsk.type, lrn, fnames))
    req(length(ind) != 0L)
    req(length(feats) != 0L)
    if (tsk.type == "classif") {
      if (ind == "Yes") {
        clist = list()
        clist[feats] = min(getTaskData(tsk)[feats])
        pd = generatePartialDependenceData(mod, tsk, feats, individual = ind,
        center = clist[feats])
      } else {
        pd = generatePartialDependenceData(mod, tsk, feats, individual = ind)
      }
    } else {
      pd = generatePartialDependenceData(mod, tsk, feats, individual = ind)
    }
    q = plotPartialDependence(pd)
  } else if (plot.type == "confusion matrix") {
    q = NULL
  } else if (plot.type == "ROC") {
    checkPlotROCCurves(lrn)
      df = generateThreshVsPerfData(preds, measures = ms)
      q = plotROCCurves(df)
  }
  return(q)
}

makeConfusionMatrix = function(plot.type, preds) {
  conf = calculateConfusionMatrix(preds)
  return(conf$result)
}

makePredictionPlotSettingsUI = function(plot.type, fnames, feats, ms.def, ms,
  tsk.type, fm, predict.type, help.texts, width = 200) {
  if (plot.type == "prediction") {
    if (help.texts)
      settings.text = htmlOutput("prediction.plot.text")
    else
      settings.text = NULL
    req(length(fnames) != 0L)
    settings.inp = selectInput("predictionplot.feat.sel", "Select variables:",
      choices = fnames, multiple = TRUE, width = width)
    settings.ui = list(
      column(width = 4, settings.inp),
      column(width = 12, settings.text)
    )
  } else if (plot.type == "residuals") {
    if (help.texts)
      settings.text = htmlOutput("residual.plot.text")
    else
      settings.text = NULL
    settings.inp = selectInput("residualplot.type", "Select type of plot:",
      choices = c("scatterplot", "histogram"), selected = "scatterplot",
      width = width)
    settings.ui = list(
      column(4, settings.inp),
      column(width = 12, settings.text)
    )
  } else if (plot.type == "partial dependency") {
    if (help.texts)
      settings.text = htmlOutput("partial.dep.plot.text")
    else
      settings.text = NULL
    req(length(fnames) != 0L)
    settings.inp = selectInput("predictionplot.feat.sel", "Select variables:",
        choices = fnames, selected = getFirst(fnames), multiple = FALSE, width = width)
    if (predict.type != "se") {
      settings.ind = radioButtons("pd.plot.ind", "Individual expectation?", 
        choices = c("Yes" = "TRUE", "No" = "FALSE"), inline = TRUE, selected = "FALSE")
    } else
      settings.ind = NULL
    
    settings.ui = list(
      column(width = 4, settings.inp),
      column(width = 4, settings.ind),
      column(width = 12, settings.text)
    )
  } else if (plot.type == "confusion matrix") {
    if (help.texts)
      settings.text = htmlOutput("confusion.matrix.text")
    else
      settings.text = NULL
    settings.ui = column(width = 12, settings.text)
  } else if (plot.type == "ROC") {
    if (help.texts)
      settings.text = htmlOutput("roc.plot.text")
    else
      settings.text = NULL
    settings.ui = column(width = 12, settings.text)
  }
  return(settings.ui)
}


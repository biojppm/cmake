
function dbg()
{
  /* pass ?dbg=1 to enable debug logs */
  /*if(!getParam('dbg', 0)){
    return;
  }*/
  elm = $("#dbg");
  var s = "";
  for (var i = 0; i < arguments.length; i++) {
    if(i > 0) s += ' ';
    s += arguments[i].toString();
  }
  s+= "\n";
  elm.append(document.createTextNode(s));
}


function iterArr(arr, fn) {
  for (var key in arr) {
     if (arr.hasOwnProperty(key)) {
       fn(key, arr[key]);
     }
  }
}


function fileContents(file, onComplete)
{
  dbg(`${file}: requesting...`);
  var data;
  $.get(file, function(d) {
    dbg(`${file}: got response! ${d.length}B...`);
    if(onComplete) {
      onComplete(d);
    }
  }, "text");
}



/* https://stackoverflow.com/questions/7394748/whats-the-right-way-to-decode-a-string-that-has-special-html-entities-in-it/7394787 */
function decodeHtmlEntities(str)
{
  return str
    .replace("&amp;", "&")
    .replace("&lt;", "<")
    .replace("&gt;", ">")
    .replace("&quot;", "\"")
    .replace(/&#(\d+);/g, function(match, dec) {
      return String.fromCharCode(dec);
    });
}
/* https://stackoverflow.com/questions/6234773/can-i-escape-html-special-chars-in-javascript */
function escapeHtml(unsafe)
{
    return unsafe
         .replace(/&/g, "&amp;")
         .replace(/</g, "&lt;")
         .replace(/>/g, "&gt;")
         .replace(/"/g, "&quot;")
         .replace(/'/g, "&#039;");
}


/* URL params ----------------------------------------------------------------- */

var _curr_url_params = null;
function parseUrlParams()
{
  var keyvals = [];
  var keys = document.location.search.substring(1).split('&');
  dbg("keys=", keys)
  for(var i = 0; i < keys.length; i++) {
    var key = keys[i].split('=');
    dbg("i=", i, "  key=", key);
    keyvals.push(key[0]);
    keyvals[key[0]] = key[1];
  }
  _curr_url_params = keyvals;
}

function dbgParams() {
  iterArr(_curr_url_params, function(key, val){ dbg("url params:", key, "=", val); })

}
function getParam(name, fallback)
{
  if(_curr_url_params === null) { parseUrlParams(); }
  if(name in _curr_url_params) {
    return _curr_url_params[name];
  }
  return fallback;
}

function setParam(name, value) {
  if(_curr_url_params === null) { parseUrlParams(); }
  _curr_url_params[name] = value;
  // https://stackoverflow.com/questions/486896/adding-a-parameter-to-the-url-with-javascript
  document.location.search = joinParams();
}

function joinParams() {
  if(_curr_url_params === null) { parseUrlParams(); }
  var s = "";
  iterArr(_curr_url_params, function(key, val){
    if(s != ""){ s += '&'; }
    s += `${key}=${val}`;
  });
  return s;
}


/* ----------------------------------------------------------------------------- */

function colMax(data, col)
{
  var max = -1.e30;
  data.forEach(function(item, index){
    max = item[col] > max ? item[col] : max;
  });
  return max;
}

function colMin(data, col)
{
  var min = 1.e30;
  data.forEach(function(item, index){
    min = item[col] < min ? item[col] : min;
  });
  return min;
}

/* https://stackoverflow.com/questions/2283566/how-can-i-round-a-number-in-javascript-tofixed-returns-a-string */
function toFixedNumber(num, digits, base)
{
  var pow = Math.pow(base||10, digits);
  return Math.round(num*pow) / pow;
}

function humanReadable(sz, base=1024, precision=3)
{
  var i = -1;
  var units;
  if(base == 1000)
  {
    units = ['k', 'M', 'G', 'T', 'P', 'E', 'Z', 'Y'];
  }
  else if(base == 1024)
  {
    units = ['ki', 'Mi', 'Gi', 'Ti', 'Pi', 'Ei', 'Zi', 'Yi'];
  }
  do
  {
    sz /= base;
    i++;
  } while (sz > base);
  return sz.toFixed(precision) + units[i];
};


/* ----------------------------------------------------------------------------- */

class BmResults
{
  constructor(dict={})
  {
    Object.assign(this, dict);
    for(var i = 0; i < this.benchmarks.length; ++i) {
      var bm = this.benchmarks[i];
      bm.name = decodeHtmlEntities(bm.name);
      bm.run_name = decodeHtmlEntities(bm.run_name);
    }
  }
}

var bmSpecs;
function iterBms(fn)
{
  iterArr(bmSpecs.benchmarks, fn);
}

function loadSpecs(specs)
{
  dbg("loading specs ....");
  $("#heading-title").html(`Benchmarks: ${specs.name}`);
  bmSpecs = specs;
  var toc = $("#toc");
  /*toc.append(`<li><a href="#" onclick="setParam('bm', 'all');">Load all</a></li>`);*/
  iterBms(function(key, bm) {
    toc.append(`<li><a href="#${key}" onclick="setParam('bm', '${key}');">${key}</a>: ${bm.desc}</li>`)
    bm.name = key;
  });
  // load if required
  currBm = getParam("bm", "");
  dbg("params=", _curr_url_params, currBm);
  if(currBm != "") {
    dbg("loading BM from URL:", currBm)
    loadBm(currBm);
  }
}

function normalizeBy(results, column_name, best_fn)
{
  var best = best_fn(results.benchmarks, column_name);
  results.benchmarks.forEach(function(item, index){
    item[`${column_name}_normalized`] = item[column_name] / best;
  });
}


function loadAll()
{
  var id = "#bm-results";
  $(id).empty();
  var i = 0;
  iterBms(function(key, bm){
    if(i++ > 0) $(id).append("<div class='bm-sep'><hr/></div>");
    appendBm(key);
  });
}


function loadBm(key)
{
  dbg("loading-.....", key);
  /*if(key == "all") {
    loadAll();
  }*/
  $("#bm-results").empty();
  var bm = bmSpecs.benchmarks[key];
  if(bm.src != "") {
    fileContents(bm.src, function(data){
      dbg(`${key}: got src data!`)
      bm.src_data = data;
    });
  }
  fileContents("bm/"+bm.results, function(data){
    dbg(`${key}: got bm data!`)
    bm.results_data = new BmResults(JSON.parse(data));
    bm.results_data.benchmarks.forEach(function(item, index){
      item.id = index;
    });
    normalizeBy(bm.results_data, 'iterations', colMin);
    normalizeBy(bm.results_data, 'real_time', colMin, );
    normalizeBy(bm.results_data, 'cpu_time', colMin);
    normalizeBy(bm.results_data, 'bytes_per_second', colMin);
    normalizeBy(bm.results_data, 'items_per_second', colMin);
    appendBm(key, bm);
  });
}


function appendBm(id, bm)
{
  if($(document).find(`bm-results-${id}`).length == 0)
  {
    $("#bm-results").append(`
<div id="bm-results-${id}">
  <h2 id="bm-title-${id}">${id}</h2>

  <h3 id="heading-table-${id}">Result tables</h3>
  <h4 id="heading-table-${id}_pretty">Results</h4><table id="table-${id}_pretty" class="datatable" width="800px"></table>
  <h4 id="heading-table-${id}_normalized">Normalized by column min</h4><table id="table-${id}_normalized" class="datatable" width="800px"></table>

  <h3 id="heading-chart-${id}">Chart</h2>
  <div id="chart-container-${id}"></div>

  <h3 id="heading-code-${id}">Code</h2>
  <pre><code id="code-${id}" class="lang-c++"></code></pre>
</div>

`);
  }
  var results = bm.results_data;
  var code = bm.src_data;
  loadTable(id, bm, results);
  loadChart(id, bm, results);
  loadCode(id, bm, code);
}


function loadCode(elmId, bm, code)
{
  var elm = $(`#code-${elmId}`);
  elm.text(code);
  /*  hljs.highlightBlock(elm); // this doesn't work */
  /*  ... and this is very inefficient: */
  document.querySelectorAll('pre code').forEach((block) => {
    hljs.highlightBlock(block);
  });
}


function loadTable(id, bm, results)
{
  function render_int(data, type, row, meta) { return toFixedNumber(data, 0); }
  function render_megas(data, type, row, meta) { return toFixedNumber(data / 1.e6, 3); }
  function render_fixed(data, type, row, meta) { return toFixedNumber(data, 3); }
  function render_human(data, type, row, meta) { return humanReadable(data, 1000, 3); }

  addTable("_pretty"    , ""           , {ns: render_int, iters: render_megas, rates: render_megas});
  addTable("_normalized", "_normalized", {ns: render_fixed, iters: render_fixed, rates: render_fixed});

  function addTable(suffix, data_suffix, renderers) {
    /*  https://datatables.net/ */
    var searching = (results.benchmarks.count > 20);
    var ratePrefix = renderers.rates == render_megas ? "M" : "";
    var iterPrefix = renderers.iters == render_megas ? "M" : "";
    var clockSuffix = data_suffix == "_normalized" ? "" : "(ns)";
    $(`#table-${id}${suffix}`).DataTable( {
      data: results.benchmarks,
      info: false,
      paging: false,
      searching: searching,
      retrieve: searching,
      /*  https://datatables.net/reference/option/columns.type */
      columns: [
        {title: "ID", data: "id", type: "num"},
        {title: "Name", data: "name", render: function(data, type, row, meta) { return escapeHtml(data); }},
        {title: `${ratePrefix}B/s`       , data: `bytes_per_second${data_suffix}`, type: "num", className: "text-right", render: renderers.rates},
        {title: `${ratePrefix}items/s`   , data: `items_per_second${data_suffix}`, type: "num", className: "text-right", render: renderers.rates},
        {title: `Clock${clockSuffix}`    , data: `real_time${data_suffix}`       , type: "num", className: "text-right", render: renderers.ns},
        {title: `CPU${clockSuffix}`      , data: `cpu_time${data_suffix}`        , type: "num", className: "text-right", render: renderers.ns},
        {title: `${ratePrefix}Iterations`, data: `iterations${data_suffix}`      , type: "num", className: "text-right", render: renderers.iters},
      ]});
  }
}

function loadChart(id, bm, results)
{

  addChartFromColumn('bytes_per_second_normalized', "B/s", "(more is better)");
  addChartFromColumn('items_per_second_normalized', "items/s", "(more is better)");
  addChartFromColumn('iterations_normalized', "Iterations", "(more is better)");
  addChartFromColumn('real_time_normalized', "Clock time", "(less is better)");
  addChartFromColumn('cpu_time_normalized', "CPU time", "(less is better)");

  function addChartFromColumn(column, column_name, obs) {
    var elmId = `chart-${id}-${column}`;
    var canvas = `${elmId}-canvas`;

    $(`#chart-container-${id}`).append(`
<div id="${elmId}" class="chart">
  <canvas id="${canvas}"></canvas>
</div>
`);

    var chart = new CanvasJS.Chart(elmId, {
      animationEnabled: false,
      title:{
        fontSize: 24,
        /* text: `${id}: ${column_name}\n${obs}` */
        text: `${column_name}\n${obs}`
      },
      axisX: {
          labelFontSize: 12,
      },
      data: [{
        type: "bar",
        axisYType: "secondary",
        color: "#eb7434",/*"#014D65",*/
        dataPoints: results.benchmarks.map(function(item){
          return {
            indexLabelFormatter: function(e) { return e.dataPoint.indexLabel; },
            indexLabelFontSize: 16,
            indexLabel: item.name,
            /* label: item.name, */
            y: item[column],
            /* save the result here: the tooltip will show the full thing */
            benchmark_results: item
          };
        }),
      }],
      toolTip: {
        /*content: "{indexLabel}: {y}",*/
        contentFormatter: function(e){
          function hr(val) { return humanReadable(val, 1000, 3); }
          function fx(val) { return toFixedNumber(val, 3); }
          function fxi(val) { return toFixedNumber(val, 0); }
          function getRow(name, abs, rel) { return `<tr><td>${name}</td><td>${abs}</td><td>${rel}x min</td></tr>`; }
          var r = e.entries[0].dataPoint.benchmark_results;
          var hdrRow = `<tr><th></th><th>Absolute</th><th>Normalized</th></tr>`;
          var bpsRow = getRow("B/s", hr(r.bytes_per_second), fx(r.bytes_per_second_normalized));
          var ipsRow = getRow("items/s", hr(r.items_per_second), fx(r.items_per_second_normalized));
          var cpuRow = getRow("CPU", fxi(r.cpu_time) + "ns", fx(r.cpu_time_normalized));
          var clockRow = getRow("Clock", fxi(r.real_time) + "ns", fx(r.real_time_normalized));
          var itersRow = getRow("Iterations", hr(r.iterations), fx(r.iterations_normalized));
          var table = `<table>${hdrRow}${bpsRow}${ipsRow}${cpuRow}${clockRow}${itersRow}</table>`;
          return `<h4>${escapeHtml(r.name)}</h4>${table}`;
        }
      }
    });
    chart.render();
  }
}

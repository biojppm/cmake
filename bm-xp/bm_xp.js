

function urlParams()
{
  var vars = [], hash;
  var hashes = window.location.href.slice(window.location.href.indexOf('?') + 1).split('&');
  for(var i = 0; i < hashes.length; i++)
  {
    hash = hashes[i].split('=');
    vars.push(hash[0]);
    vars[hash[0]] = hash[1];
  }
  return vars;
}


var params = null;
function getParam(name, fallback)
{
  if(params === null) {
    params = urlParams();
  }
  if(name in params) {
    return params[name];
  }
  return fallback;
}


function dbg()
{
  //return; // comment out to enable dbg logs
  elm = $("#dbg");
  var s = "";
  for (var i = 0; i < arguments.length; i++) {
    s += arguments[i].toString();
  }
  s+= "\n";
  elm.append(document.createTextNode(s));
}


function fileContents(file, complete)
{
  dbg(`${file}: requesting...`);
  var data;
  $.get(file, function(d) {
    dbg(`${file}: got response! ${d.length}B...`);
    if(complete) complete(d);
  }, "text");
}


function escapeHTML(unsafeText) {
  let div = document.createElement('div');
  div.innerText = unsafeText;
  safeText = div.innerHTML;
  return safeText;
}


class BmResults
{
  constructor(dict={})
  {
    Object.assign(this, dict);
    for(var i = 0; i < this.benchmarks.length; ++i) {
      var bm = this.benchmarks[i];
      bm.name = escapeHTML(bm.name);
      bm.run_name = escapeHTML(bm.run_name);
    }
  }
}


var bmSpecs;
function iterBms(fn)
{
  for (var key in bmSpecs.benchmarks) {
     if (bmSpecs.benchmarks.hasOwnProperty(key)) {
       fn(key, bmSpecs.benchmarks[key]);
     }
  }
}


function loadSpecs(specs) {
  dbg("loading specs ....");
  $("#heading-title").html(`Benchmarks: ${specs.name}`);
  bmSpecs = specs;
  var toc = $("#toc");
  toc.append(`<li><a href="#" onclick="loadAll();">Load all</a></li>`)
  iterBms(function(key, bm) {
    toc.append(`<li><a href="#bm-title-${key}" onclick="loadBm('${key}');">${key}</a>: ${bm.desc}</li>`)
    bm.name = key;
    fileContents(bm.src, function(data){
      dbg(`${key}: got src data!`)
      bm.src_data = data;
    });
    fileContents(bm.results, function(data){
      dbg(`${key}: got bm data!`)
      bm.results_data = new BmResults(JSON.parse(data));
      bm.results_data.benchmarks.forEach(function(item, index){
        item.id = index;
      });
      normalizeBy(bm.results_data, 'iterations');
      normalizeBy(bm.results_data, 'real_time');
      normalizeBy(bm.results_data, 'cpu_time');
      normalizeBy(bm.results_data, 'bytes_per_second');
      normalizeBy(bm.results_data, 'items_per_second');
    });
  });
}


function normalizeBy(results, column_name)
{
  var min = 1.e30;
  results.benchmarks.forEach(function(item, index){
    min = item[column_name] < min ? item[column_name] : min;
  });
  results.benchmarks.forEach(function(item, index){
    item[`${column_name}_normalized`] = item[column_name] / min;
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


function loadBm(id)
{
  $("#bm-results").empty();
  appendBm(id);
}


function appendBm(id)
{
  if($(document).find(`bm-results-${id}`).length == 0)
  {
    $("#bm-results").append(`
<div id="bm-results-${id}">
  <h2 id="bm-title-${id}">${id}</h2>

  <h3 id="heading-table-${id}">Table</h2>
  <table id="table-${id}" class="datatable" width="100%"></table>

  <h3 id="heading-chart-${id}">Chart</h2>
  <div id="chart-container-${id}"></div>

  <h3 id="heading-code-${id}">Code</h2>
  <pre><code id="code-${id}" class="lang-c++"></code></pre>
</div>

`);
  }
  var bm = bmSpecs.benchmarks[id];
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
  // hljs.highlightBlock(elm); // this doesn't work
  // ... and this is very inefficient:
  document.querySelectorAll('pre code').forEach((block) => {
    hljs.highlightBlock(block);
  });
}


function loadTable(id, bm, results)
{
  var elmId = `#table-${id}`;
  var cols = [
    {title: "ID", data: "id", type: "num"},
    {title: "Name", data: "name"},
    {title: "Iterations", data: "iterations", type: "num"},
    {title: "Clock", data: "real_time_normalized", type: "num"},
    {title: "CPU", data: "cpu_time_normalized", type: "num"},
    {title: "B/s", data: "bytes_per_second_normalized", type: "num"},
    {title: "items/s", data: "items_per_second_normalized", type: "num"}
  ];
  $(elmId).DataTable( {
    data: results.benchmarks,
    paging: false,
    searching: true,
    retrieve: true,
    columns: cols
  });
}


function loadChart(id, bm, results)
{

  addChartColumn('iterations_normalized', "Iterations", "(more is better)");
  addChartColumn('real_time_normalized', "Real time (ns)", "(less is better)");
  addChartColumn('cpu_time_normalized', "CPU time (ns)", "(less is better)");
  addChartColumn('bytes_per_second_normalized', "B/s", "(more is better)");
  addChartColumn('items_per_second_normalized', "items/s", "(more is better)");

  function addChartColumn(column, column_name, obs) {
    var elmId = `chart-${id}-${column}`;
    var canvas = `${elmId}-canvas`;
    $(`#chart-container-${id}`).append(`
<div id="${elmId}" class="chart">
  <canvas id="${canvas}"></canvas>
</div>
`);


    // https://sashat.me/2017/01/11/list-of-20-simple-distinct-colors/
    var colors = [
      '#e6194b', '#3cb44b', '#ffe119', '#4363d8', '#f58231', '#911eb4', '#46f0f0', '#f032e6', '#bcf60c',
      '#fabebe', '#008080', '#e6beff', '#9a6324', '#fffac8', '#800000', '#aaffc3', '#808000', '#ffd8b1',
      '#000075', '#808080', '#ffffff', '#000000'
    ]
    icolor = 3;
    function nextColor() {
      c = colors[icolor];
      icolor = (icolor + 1) % colors.length;
      return c;
    }

    var data = []
    results.benchmarks.forEach(function(item, index){
      data.push({
        label: item.name,
        y: item[column],
        //color: nextColor()
      });
    });

    var chart = new CanvasJS.Chart(elmId, {
      animationEnabled: false,
      title:{
        text: `${id}: ${column_name} ${obs}`
      },
      axisY: {
        title: column_name,
      },
      data: [{
        type: "bar",
        axisYType: "secondary",
        color: "#014D65",
        dataPoints: data
      }]
    });
    chart.render();
  }

  function addChartColumnOld(column, column_name, obs) {
    var elmId = `chart-${id}-${column}`;
    $(`#chart-container-${id}`).append(`<div id="${elmId}" class="chart"></div>`);


    // https://sashat.me/2017/01/11/list-of-20-simple-distinct-colors/
    var colors = [
      '#e6194b', '#3cb44b', '#ffe119', '#4363d8', '#f58231', '#911eb4', '#46f0f0', '#f032e6', '#bcf60c',
      '#fabebe', '#008080', '#e6beff', '#9a6324', '#fffac8', '#800000', '#aaffc3', '#808000', '#ffd8b1',
      '#000075', '#808080', '#ffffff', '#000000'
    ]
    icolor = 3;
    function nextColor() {
      c = colors[icolor];
      icolor = (icolor + 1) % colors.length;
      return c;
    }

    var data = []
    results.benchmarks.forEach(function(item, index){
      data.push({
        label: item.name,
        y: item[column],
        //color: nextColor()
      });
    });

    var chart = new CanvasJS.Chart(elmId, {
      animationEnabled: false,
      title:{
        text: `${id}: ${column_name} ${obs}`
      },
      axisY: {
        title: column_name,
      },
      data: [{
        type: "bar",
        axisYType: "secondary",
        color: "#014D65",
        dataPoints: data
      }]
    });
    chart.render();
  }
}


function humanReadable(sz, base=1024, precision=3)
{
  var i = -1;
  var units;
  if(base == 1000)
  {
    units = ['kB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB'];
  }
  else if(base == 1024)
  {
    units = ['kiB', 'MiB', 'GiB', 'TiB', 'PiB', 'EiB', 'ZiB', 'YiB'];
  }
  do
  {
    sz /= base;
    i++;
  } while (sz > base);
  return sz.toFixed(precision) + units[i];
};

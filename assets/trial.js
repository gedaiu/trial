var icons = {
  "created":  "hourglass",
  "started":  "fas fa-hourglass-half",
  "unknown":  "fas fa-question",
  "failure":  "fas fa-times",
  "skip":     "far fa-dot-circle",
  "pending":  "far fa-circle",
  "success":  "fas fa-check",
  "duration": "fas fa-clock"
}

var cards = {
  "duration": "border-success",
  "success":  "bg-success text-white",
  "created":  "bg-dark text-white",
  "started":  "bg-dark text-white",
  "unknown":  "bg-warning text-white",
  "failure":  "bg-danger text-white",
  "skip":     "bg-warning text-white",
  "pending":  "bg-info text-white"
}

var detailsIndex = 0;

$(function() {
  buildResults($("#test-results"), window.results);

  var suiteOverview = getSuitesOverview(window.results);

  $("#overview").append(buildCard("duration", niceDuration(suiteOverview["duration"])));

  Object.keys(suiteOverview).filter(a => a != "duration").forEach(key => {
    var action = "asd";
    $("#overview").append(buildCard(key, suiteOverview[key], action));
  });

  $("#search").on("input", function() {
    $("#view-options .btn").removeClass("active");
    $("#view-options .btn:first").addClass("active");

    var value = $(this).val();

    if(value != "") {
      $(".test").each(function() {
        var t = $(this);

        if(t.find("h2").text().indexOf(value) == -1) {
          t.addClass("d-none");
        } else {
          t.removeClass("d-none");
        }
      });
    } else {
      $(".test.d-none").removeClass("d-none");
    }

    updateSuiteVisibility();
  }).trigger("input");

  if($(".test.failure").length == 0) {
    $("#view-options").addClass("d-none");
  }

  $("#view-options").click(function() {
    if(!$("#view-all").parent().is(".active")) {
      $(".test, .suite").removeClass("d-none");
      return;
    }

    $(".test:not(.failure)").addClass("d-none");
    updateSuiteVisibility();
  });
});

function updateSuiteVisibility() {
  $(".suite").each(function() {
    var t = $(this);
    var visibleChilds = t.find(".test:not(.d-none)").length;

    if(visibleChilds == 0) {
      $(this).addClass("d-none");
    } else {
      $(this).removeClass("d-none");
    }
  });
}

function niceDuration(value) {
  let h = 0;
  let m = 0;
  let s = 0;

  if(value >= 3600 * 1000) {
    h = parseInt(value / (3600 * 1000));
    value -= h * (3600 * 1000);
  }

  if(value >= 60 * 1000) {
    m = parseInt(value / (60 * 1000));
    value -= m * (60 * 1000);
  }

  if(value >= 1000) {
    s = parseInt(value / 1000);
    value -= s * 1000;
  }

  var result = [];

  if(h > 0) {
    result.push(h + "h")
  }

  if(m > 0) {
    result.push(m + "m")
  }

  if(s > 0) {
    result.push(s + "s")
  }

  if(value >= 0) {
    result.push(value + "ms")
  }

  return result.join(" ");
}

function classDuration(value) {
  if(value >= dangerTestDuration) {
    return "text-danger";
  }

  if(value >= warningTestDuration) {
    return "text-warning";
  }

  if(value >= warningTestDuration) {
    return "text-info";
  }
}


function buildCard(key, value, action) {
  var button = "";

  if(action) {
    button = `
    <div class="card-footer text-muted">
      <button type="button" class="btn btn-link">Hide</button>
    </div>`;
  }

  return `<div class="card ${cards[key]} mb-3" style="max-width: 18rem;">
  <div class="card-body">
    <h5 class="card-title">${value}</h5>
    <p class="card-text">${key}</p>
  </div>
</div>`;
}

function buildResults(collection, results) {
  results.forEach(element => {
    var duration = niceDuration(new Date(element.end) - new Date(element.begin));
    var overview = getSuiteOverview(element);

    var overviewHtml = Object.keys(overview)
      .filter(a => a != "duration")
      .map(a => `<span class="${icons[a]}" aria-hidden="true"></span> ${overview[a]}`)
      .join("&nbsp;&nbsp;&nbsp;");

    collection.append(`<div class="suite" data-suite-name="${encodeURI(element.name)}">
      <h1>${element.name}</h1>
      <p class="suite-overview">
        <span class="${icons["duration"]}" aria-hidden="true"></span> ${duration}&nbsp;&nbsp;&nbsp;${overviewHtml}
      </p>
      <hr>
      <div class="test-list"></div>
      </div>`);

    buildTestResults($("#test-results .suite:last .test-list"), element.tests);
  });
}

function buildTestResults(collection, results) {
  results.forEach(element => {
    var extra = "";
    var detailsId = "";
    var duration = new Date(element.end) - new Date(element.begin);
    
    extra = `<span class="${classDuration(duration)}"><span class="${icons["duration"]}" aria-hidden="true"></span></span> ${niceDuration(duration)}`;

    if(element.throwable.raw) {
      detailsId = `test-details-${detailsIndex}`;
      extra += `<button type="button" class="btn btn-link" data-toggle="collapse" data-target="#${detailsId}">details</button>`;
      detailsIndex++;
    }

    var result = `<div class="test ${element.status}" data-test-name="${encodeURI(element.name)}">
      <h2>
        <span class="result-icon"><span class="${icons[element.status]}" aria-hidden="true"></span></span> ${element.name} 
        <small>${extra}</small>
        </h2>`;

    if(element.throwable.msg) {
      result += `<div class="collapse" id="${detailsId}"><pre class="rounded"><code>${element.throwable.msg}</code><pre></div>`
    }
    
    result += '</div>';

    collection.append(result);
  });
}

function getSuitesOverview(suiteList) {
  var overview = {};

  suiteList.forEach(suite => {
    var result = getSuiteOverview(suite);
    
    Object.keys(result).forEach(key => {
      if(!overview[key]) {
        overview[key] = 0;
      }

      overview[key] += result[key];
    });
  });

  return overview;
}

function getSuiteOverview(suite) {
  var overview = {};

  suite.tests.forEach(test => {
    if(!overview[test.status]) {
      overview[test.status] = 0;
    }

    overview[test.status]++;
  });

  var begin = new Date(suite.begin);
  var end = new Date(suite.end);

  overview.duration = end - begin;
  return overview;
}
var icons = {
  "created": "clock",
  "started": "loop-square",
  "unknown": "question-mark",
  "failure": "x",
  "skip": "media-step-forward",
  "pending": "clock",
  "success": "check"
}

$(function() {
  buildResults($("#test-results"), window.results);
});

function buildResults(collection, results) {
  results.forEach(element => {
    collection.append('<div class="suite" data-suite-name="' + encodeURI(element.name) + '">'+
      '<h1>' + element.name + '</h1><hr>' +
      '<div class="test-list"></div>' +
      '</div>');

    buildTestResults($("#test-results .suite:last .test-list"), element.tests);
  });
}

function buildTestResults(collection, results) {
  results.forEach(element => {
    var result = '<div class="test ' + element.status + '" data-test-name="' + encodeURI(element.name) + '">'+
    '<h2><span class="oi oi-' + icons[element.status] + '" aria-hidden="true"></span> ' + element.name + '</h2>';

    if(element.throwable.raw) {
      result += '<pre class="rounded"><code>' + element.throwable.raw + '</code><pre>'
    }
    
    result += '</div>';

    collection.append(result);
  });
}
function makeFunc() {
  var browser = 'Mozilla';
  function displayName() {
    alert(browser);
    var message = 'hello ' + browser;
    alert(message);
  }
  return displayName;
}

var myFunc = makeFunc();
myFunc();

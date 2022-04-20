import fetch from 'node-fetch';

async function openBrowser() {
  const { Builder, By, Key, until } = require('selenium-webdriver');
  const safari = require('selenium-webdriver/safari');

  let options = new safari.Options();
  let driver = await new Builder()
    .forBrowser('safari')
    .setSafariOptions(options)
    .build();

  await driver.get('http://localhost/sunset-quality-predictor/model/predict.html#today');

  let minutesToKeepPageOpen = 5;

  await driver.sleep(minutesToKeepPageOpen * 60 * 1000);

  await driver.quit();
}

// openBrowser();

isItTimeYet();

function subtractHours(numOfHours, date) {
  date.setHours(date.getHours() - numOfHours);

  return date;
}

function compareTimes(first, second) {
  return Math.round(Math.abs(first - second) / 60 / 1000);
}

async function isItTimeYet() {
  let now = new Date();
  let todayYYYYMMDD = `${now.toLocaleDateString('en-US', { year: 'numeric' })}-${now.toLocaleDateString('en-US', { month: '2-digit' })}-${now.toLocaleDateString('en-US', { day: '2-digit' })}`;

  let sunsetTimeRequest = await fetch(`http://skyline.noshado.ws/sunset-api-proxy/getSunsetTime.php?lat=40.730610&lng=-73.935242&date=${todayYYYYMMDD}&timezone=ET`);
  let sunsetTimeResponse = await sunsetTimeRequest.json();

  let sunsetTime = new Date(sunsetTimeResponse.timestamp * 1000);

  console.log(`Now: ${now}`);
  console.log(`Sunset Time: ${sunsetTime}`);
  console.log(`Difference Between Now and Sunset Time in Minutes: ${compareTimes(new Date(), sunsetTime)}`);
}

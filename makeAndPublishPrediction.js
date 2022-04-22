import fetch from 'node-fetch';
import { SECRETS } from './config.js';

function subtractHours(numOfHours, date) {
  date.setHours(date.getHours() - numOfHours);

  return date;
}

function compareTimes(first, second) {
  return Math.round(Math.abs(first - second) / 60 / 1000);
}

async function checkIfPredictionAlreadyPublished(date) {
  let request = await fetch(`${SECRETS.PUBLISH_SERVER_URL}history/predictions/${date}.json`);

  return request.ok;
}

async function publishPrediction() {
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

async function checkEligibility() {
  // let now = new Date('2022-03-25T18:16:00'); // DEBUG
  let now = new Date();
  let todayYYYYMMDD = `${now.toLocaleDateString('en-US', { year: 'numeric' })}-${now.toLocaleDateString('en-US', { month: '2-digit' })}-${now.toLocaleDateString('en-US', { day: '2-digit' })}`;

  let sunsetTimeRequest = await fetch(`${SECRETS.SUNSET_API_PROXY_URL}?lat=40.730610&lng=-73.935242&date=${todayYYYYMMDD}&timezone=ET`);
  let sunsetTimeResponse = await sunsetTimeRequest.json();

  let sunsetTime = new Date(sunsetTimeResponse.timestamp * 1000);
  let oneHourBeforeSunsetTime = subtractHours(1, sunsetTime);

  // DEBUG
  // console.log(`Now: ${now}`);
  // console.log(`Sunset Time: ${sunsetTime}`);
  // console.log(`1 Hour Before Sunset Time: ${oneHourBeforeSunsetTime}`);
  // console.log(`Difference Between Now and Sunset Time in Minutes: ${compareTimes(now, oneHourBeforeSunsetTime)}`);

  const predictionAlreadyPublished = await checkIfPredictionAlreadyPublished(todayYYYYMMDD);

  if (!predictionAlreadyPublished && compareTimes(now, oneHourBeforeSunsetTime) <= 6) {
    console.log('OK RUN SCRIPT');
    // publishPrediction();
  }
}

checkEligibility();
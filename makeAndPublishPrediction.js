import fetch from 'node-fetch';
import { SECRETS } from './config.js';

import { Builder, By, Key, until } from 'selenium-webdriver';
import Safari from 'selenium-webdriver/safari.js';

function subtractHours(numOfHours, date) {
  let milliseconds = date.getTime();
  let millisecondsToAdd = numOfHours * 60 * 60 * 1000;
  let newDate = new Date(milliseconds - millisecondsToAdd);

  return newDate;
}

function compareTimes(first, second) {
  return Math.round(Math.abs(first - second) / 60 / 1000);
}

async function checkIfPredictionAlreadyPublished(date) {
  let request = await fetch(`http://localhost/sunset-quality-predictor/data/compositeImagesBeforeSunset/forPrediction/${date}.jpg`);

  return request.ok;
}

async function publishPrediction() {
  let options = new Safari.Options();
  let driver = await new Builder()
    .forBrowser('safari')
    .setSafariOptions(options)
    .build();

  await driver.get('http://localhost/sunset-quality-predictor/model/predict.html#today');

  let minutesToKeepPageOpen = 3.5;

  await driver.sleep(minutesToKeepPageOpen * 60 * 1000);

  await driver.quit();
}

async function checkEligibility() {
  let now = new Date();
  let todayYYYYMMDD = `${now.toLocaleDateString('en-US', { year: 'numeric' })}-${now.toLocaleDateString('en-US', { month: '2-digit' })}-${now.toLocaleDateString('en-US', { day: '2-digit' })}`;

  let sunsetTimeRequest = await fetch(`${SECRETS.SUNSET_API_PROXY_URL}?date=${todayYYYYMMDD}&timezone=ET`);
  let sunsetTimeResponse = await sunsetTimeRequest.json();

  let sunsetTime = new Date(sunsetTimeResponse.timestamp * 1000);
  let oneHourBeforeSunsetTime = subtractHours(1, sunsetTime);

  // DEBUG
  // console.log(`Now: ${now}`);
  // console.log(`Sunset Time: ${sunsetTime}`);
  // console.log(`1 Hour Before Sunset Time: ${oneHourBeforeSunsetTime}`);
  // console.log(`Difference Between Now and Sunset Time in Minutes: ${compareTimes(now, oneHourBeforeSunsetTime)}`);

  const predictionAlreadyPublished = await checkIfPredictionAlreadyPublished(todayYYYYMMDD);

  if (!predictionAlreadyPublished && compareTimes(now, oneHourBeforeSunsetTime) <= 10) {
    publishPrediction();
  }
}

checkEligibility();

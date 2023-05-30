#!/bin/bash
set -xe

if [ -z "$APP_NAME" ]; then
    APP_NAME=${CI_PROJECT_NAME}
fi

if [ -z "$APP_VERSION" ]; then
    echo "APP Version is missing from build file"
fi

if [ -z "$APP_GIT_HASH" ]; then
    APP_GIT_HASH=${CI_COMMIT_SHORT_SHA}
fi

echo ${APP_NAME}

node --version
npm --version
npm install -g npm@8.3.1
npm --version
mkdir ${APP_NAME}

if [ -z "${S3_BUCKET}" ]; then
    S3_BUCKET=marin-build-artifacts
fi

echo "S3 BUCKET: ${S3_BUCKET}"

# ======BB_APP_VERSION UPDATE===========
#APP_VERSION=`cat package.json | grep version | head -1 | awk -F: '{ print $2 }' | sed 's/[ ",]//g'`

VERSION=${APP_VERSION}.${CI_COMMIT_SHORT_SHA}

echo ${VERSION}
echo "export BB_APP_VERSION=${APP_VERSION}" > BB_APP_VERSION

echo "registry=https://nexus.releng.pearsondev.com/repository/npm-all/" >> ~/.npmrc
echo "_auth=${NODE_AUTH_ID}" >> ~/.npmrc
echo "email=${NODE_EMAIL}" >> ~/.npmrc
echo "always-auth=true" >> ~/.npmrc
npm install --verbose
npm install newrelic

# After successful install, run the npm test to generate code coverage report
# If the code coverage is less than the above mentioned threshold then the test will fail with the errors and you will not able to proceed.
# npm run test

# # After successful test copying report files to gitlab artifacts
# # create a directory named "code-coverage-reports"
# mkdir $CI_PROJECT_DIR/code-coverage-reports
# # Copy html report to the new directory
# cp $CI_PROJECT_DIR/./coverage/index.html $CI_PROJECT_DIR/code-coverage-reports/
# # Copy & Rename Json summary report to the newly created
# cp $CI_PROJECT_DIR/./coverage/coverage-summary.json $CI_PROJECT_DIR/code-coverage-reports/npm-coverage-summary.json

# Start sonar analysis
echo "Sonar code analysis - Started"
./node_modules/sonarqube-scanner/src/bin/sonar-scanner -Dsonar.branch.name=$CI_COMMIT_REF_NAME
echo "Sonar code analysis - Completed"

# Remove any sonar files
rm -rf .scannerwork

ARTIFACT_ZIP=${APP_VERSION}.${APP_GIT_HASH}.zip
#zip -rq "${ARTIFACT_ZIP}" crystallake -x "crystallake/test/*" "*/\.*" "crystallake/coverage/*"
zip -r "${ARTIFACT_ZIP}" .
rm -rf amicodebuild

# Create Working Directory
mkdir amicodebuild
cp -r ${ARTIFACT_ZIP} amicodebuild/
cp -r Dockerfile amicodebuild/

# Copy .zip file to S3
aws --version
export AWS_DEFAULT_REGION=us-east-1

# Copy artifacts to s3
echo "Uploading to S3 Bucket........."
aws s3 cp ${ARTIFACT_ZIP} s3://${S3_BUCKET}/${APP_NAME}/ --acl bucket-owner-full-control
echo "Uploading is completed........."

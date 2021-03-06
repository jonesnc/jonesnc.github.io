---
title: "How to deploy GQLify to Firebase Functions"
excerpt: "Tutorial that describes how to deploy GQLify to Firebase Functions."
comments: true
tags: 
  - gqlify
  - firebase
  - firebase-functions
toc: true
---

This tutorial will walk you through the process of deploying `GQLify` to `Firebase Functions`. If you're already familiar with `GQLify` and `Firebase Functions`, skip to [Preliminary Setup](#preliminary-setup). While `GQLify` does support `Firebase Realtime Database`, this tutorial assumes you're using the `Cloud Firestore` database. 

## Introduction ##
### GQLify ###
`GQLify` vastly simplifies the process of creating a GraphQL API. The user of `GQLify` must define a collection of "models", and `GQLify` will automatically generate a series of GraphQL Queries and Mutations that allow for simple CRUD operations on those models.

For more on `GQLify`, check out their [Why GQLify](https://www.gqlify.com/docs/why-gqlify) article.

### Firebase ###
[Firebase](https://firebase.google.com/products/) is a Backend-as-a-Service (BaaS) service that provides a database service, hosting, authentication, storage, and other services for web and mobile applications.

## Preliminary Setup ##
### Requirements
* [Node.js installed](https://nodejs.org/en/download/)
* [yarn package manager installed](https://yarnpkg.com/lang/en/docs/install/#mac-stable)

### Select a firebase project ###
Open your [firebase console](https://console.firebase.google.com/) and select the project you're using, or click **Add Project** to create a new project.
### Install firebase-tools ###
Follow the [firebase setup guide](https://firebase.google.com/docs/cli/#setup) to install `firebase-tools`. 
### Authenticate firebase-tools
```bash
firebase login
```
will log in via the browser and authenticate the firebase tool.
### Start your project
```bash
mkdir myproject
cd myproject
firebase init functions
```

You will then be prompted to select the project that you'll be using with `firebase-tools`. Select the project you selected/created above.

You will also be prompted to choose a language that you'll use to write your Cloud Functions. This tutorial assumes you selected TypeScript.

Next, I'll leave it up to you whether you want to run TSLint before the compilation is performed.

Next, you'll be prompted to install dependencies. If you say `n` to this, you can run `yarn install` at any point to install dependencies.

### Install additional dependencies
```bash
cd myproject/functions
yarn install
yarn add @gqlify/firestore @gqlify/server apollo-server apollo-server-cloud-functions graphql
yarn remove typescript && yarn add typescript
yarn add -D @firebase/app-types @firebase/firestore-types @types/graphql
```

## Setup GQLify
### Create a GraphQL Schema
Create a `demo.graphql` file that will contain our GQLify models in the `myproject/functions/src` directory.
```bash
cd myproject/functions/src
touch demo.graphql
```

Paste the following code into `demo.graphql`.
```graphql
type User @GQLifyModel(dataSource: "firestore", key: "users") {
  id: ID! @unique @autoGen # auto generate unique id
  username: String!
  email: String
  books: [Book!]!
}

type Book @GQLifyModel(dataSource: "firestore", key: "books") {
  id: ID! @unique @autoGen # auto generate unique id
  name: String!
  author: [User!]!
}
```

### Get the Firestore service account JSON file
Download the `serviceAccount` JSON for the Firestore service account:

![](https://www.gqlify.com/docs/assets/data-source/firebasesdk.gif)

Once you've downloaded the JSON file, move it to the `myproject/functions/src` directory.

### Creating the server
Here we'll create the TypeScript file that sets up the `GQLify` API in a way that is compatible with `Firebase Functions`.

```bash
cd myproject/functions/src
touch index.ts
```

Paste the following code into `index.ts`:

```ts
import * as functions from "firebase-functions";
import { Gqlify } from "@gqlify/server";
import { ApolloServer } from "apollo-server-cloud-functions";
import { readFileSync } from "fs";
import { FirestoreDataSource } from "@gqlify/firestore";
const databaseUrl = "https://projectName.firebaseio.com";

// Read datamodel
const sdl = readFileSync(__dirname + "/demo.graphql", { encoding: "utf8" });
const cert = JSON.parse(
  readFileSync(__dirname + "/jsonFileName.json", {
    encoding: "utf8"
  })
);

// construct gqlify
const gqlify = new Gqlify({
  sdl,

  dataSources: {
    firestore: args => new FirestoreDataSource(cert, databaseUrl, args.key)
  }
});

const server = new ApolloServer(
  Object.assign({}, gqlify.createApolloConfig(), {
    playground: true,
    introspection: true
  })
);

exports.graphql = functions.https.onRequest((req, res) =>
  server.createHandler()(req, res)
);
```

Be sure to replace `jsonFileName.json` with the name of the serviceAccount JSON file you downloaded. For example, if the serviceAccount JSON is named `gqlify-firebase-adminsdk-a22pq-f37440b45b.json`, then your code should look like

```ts
readFileSync(__dirname + "/gqlify-firebase-adminsdk-a22pq-f37440b45b.json", {
```

Also, replace `projectName` with the name of your Firebase project. For example, if the Firebase project you selected is named `gqlify`, then your code should look like

```ts
const databaseUrl = "https://gqlify.firebaseio.com";
```

Make sure your `myproject/functions/tsconfig.json` file looks lke this:

```json
{
  "compilerOptions": {
    "lib": [
      "es6",
      "dom",
      "es2016",
      "es2017",
      "esnext.asynciterable"
    ],
    "module": "commonjs",
    "skipLibCheck": true,
    "allowSyntheticDefaultImports": true,
    "noImplicitReturns": true,
    "outDir": "lib",
    "sourceMap": true,
    "moduleResolution": "node",
    "target": "es6"
  },
  "compileOnSave": true,
  "include": [
    "src"
  ],
  "resolveJsonModule": true,
}
```

Copy the serviceAccount JSON file and `demo.graphql` file into the `myproject/functions/lib` directory. `mkdir` this directory if it doesn't exist. 

## Deploy to Firebase Functions
We can now compile and deploy our Firebase Function
```bash
cd myproject/functions
firebase deploy --only functions
```

The output of this command should look something like this:

```
=== Deploying to 'gqlify'...

i  deploying functions
Running command: npm --prefix "$RESOURCE_DIR" run lint

> functions@ lint /Users/nathanjones/Projects/gqlify-demo/functions
> tslint --project tsconfig.json

Running command: npm --prefix "$RESOURCE_DIR" run build

> functions@ build /Users/nathanjones/Projects/gqlify-demo/functions
> tsc

✔  functions: Finished running predeploy script.
i  functions: ensuring necessary APIs are enabled...
✔  functions: all necessary APIs are enabled
i  functions: preparing functions directory for uploading...
i  functions: packaged functions (121.26 KB) for uploading
✔  functions: functions folder uploaded successfully
i  functions: updating Node.js 8 function graphql(us-central1)...



✔  functions[graphql(us-central1)]: Successful update operation.

✔  Deploy complete!

Project Console: https://console.firebase.google.com/project/gqlify/overview
```

You should now be able to open your Project Console, go to the Functions page, and see your Function listed on the Dashboard page. It will list a "Trigger" URL, something that looks like `https://us-central1-gqlify.cloudfunctions.net/graphql`. The URL will be dynamically generated according to your Firebase Project name. 

If you open this URL in your browser, the GraphQL Playground should launch.

Success!

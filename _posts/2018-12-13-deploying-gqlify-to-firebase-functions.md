---
title: "Deploying GQLify to Firebase Functions"
excerpt: "Tutorial that describes how to deploy GQLify to Firebase Functions."
tags: 
  - gqlify
  - firebase
  - firebase-functions
toc: true
---

This tutorial will walk you through the process of deploying `GQLify` to `Firebase Functions`. If you're already familiar with `GQLify` and `Firebase Functions`, skip to [Setup](#Setup). While `GQLify` does support `Firebase Realtime Database`, this tutorial assumes you're using the `Cloud Firestore` database.

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
```
firebase login
```
will log in via the browser and authenticate the firebase tool.
### Start your project
```
mkdir myproject
cd myproject
firebase init functions
```
> ? Select a default Firebase project for this directory:

You will then be prompted to select the project that you'll be using with `firebase-tools`. Select the project you selected/created above.

> ? What language would you like to use to write Cloud Functions?

You will also be prompted to choose a language that you'll use to write your Cloud Functions. This tutorial assumes you selected TypeScript.

> ? Do you want to use TSLint to catch probable bugs and enforce style? (Y/n)

I'll leave it up to you whether you want to run TSLint before the compilation is performed.

> ? Do you want to install dependencies with npm now? (Y/n)

I suggest responding `Y` to this.

Your project structure should now look this:

```
myproject
 +- .firebaserc    # Hidden file that helps you quickly switch between
 |                 # projects with `firebase use`
 |
 +- firebase.json  # Describes properties for your project
 |
 +- functions/     # Directory containing all your functions code
      |
      +- .eslintrc.json  # Optional file containing rules for JavaScript linting.
      |
      +- package.json  # npm package file describing your Cloud Functions code
      |
      +- index.js      # main source file for your Cloud Functions code
      |
      +- node_modules/ # directory where your dependencies (declared in
                       # package.json) are installed
```
### Install additional dependencies
```
cd myproject/functions
yarn install
yarn add @gqlify/firestore @gqlify/server apollo-server apollo-server-cloud-functions graphql
yarn remove typescript && yarn add typescript
yarn add -D @firebase/app-types @firebase/firestore-types @types/graphql
```

## Setup GQLify
### Create a GraphQL Schema
Create a `demo.graphql` file that will contain our GQLify models in the `myproject/functions/src` directory.
```
cd myproject/functions/src
touch demo.graphql
```

Paste the following code into `demo.graphql`.
```
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

```
cd myproject/functions/src
touch index.ts
```

Paste the following code into `index.ts`:

```
import * as functions from "firebase-functions";
import { Gqlify } from "@gqlify/server";
import { ApolloServer } from "apollo-server-cloud-functions";
import { readFileSync } from "fs";
import { FirestoreDataSource } from "@gqlify/firestore";
const databaseUrl = "https://{{ projectName }}.firebaseio.com";

// Read datamodel
const sdl = readFileSync(__dirname + "/demo.graphql", { encoding: "utf8" });
const cert = JSON.parse(
  readFileSync(__dirname + "/{{ jsonFileName }}", {
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

Be sure to replace `{{ jsonFileName }}` with the name of the serviceAccount JSON file you downloaded. For example, if the serviceAccount JSON is named `gqlify-firebase-adminsdk-a22pq-f37440b45b.json`, then your code should look like

```
readFileSync(__dirname + "/gqlify-firebase-adminsdk-a22pq-f37440b45b.json", {
```

Also, replace `{{ projectName }}` with the name of your Firebase project. For example, if the Firebase project you selected is named `gqlify`, then your code should look like

```
const databaseUrl = "https://gqlify.firebaseio.com";
```

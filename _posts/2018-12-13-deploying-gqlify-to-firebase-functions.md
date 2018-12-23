---
title: "Deploying GQLify to Firebase Functions"
excerpt: "Tutorial that describes how to deploy GQLify to Firebase Functions."
tags: 
  - gqlify
  - firebase
  - firebase-functions
toc: true
---

This tutorial will walk you through the process of deploying `GQLify` to `Firebase Functions`. If you're already familiar with `GQLify` and `Firebase Functions`, skip to Step 1. While `GQLify` does support `Firebase Realtime Database`, this tutorial assumes you're using the `Cloud Firestore` database.

## Introduction ##
### GQLify ###
`GQLify` vastly simplifies the process of creating a GraphQL API. The user of `GQLify` must define a collection of "models", and `GQLify` will automatically generate a series of GraphQL Queries and Mutations that allow for simple CRUD operations on those models.

For more on `GQLify`, check out their [Why GQLify](https://www.gqlify.com/docs/why-gqlify) article.

### Firebase ###
[Firebase](https://firebase.google.com/products/) is a Backend-as-a-Service (BaaS) service that provides a database service, hosting, authentication, storage, and other services for web and mobile applications.

## Setup ##
### Select a firebase project ###
Open your [firebase console](https://console.firebase.google.com/) and select the project you're using, or click **Add Project** to create a new project.
### Install firebase-tools ###
Follow the [firebase setup guide](https://firebase.google.com/docs/cli/#setup) to install `firebase-tools`. 

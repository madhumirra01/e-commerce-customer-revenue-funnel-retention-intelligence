# E-Commerce Customer Revenue, Funnel & Retention Intelligence

An end-to-end data analytics project focused on understanding e-commerce sales performance, customer purchasing behaviour, delivery experience, and customer retention using data-driven analysis.

## Overview

E-commerce businesses generate large amounts of data through customer orders, payments, product sales, deliveries, and reviews. Analysing these datasets can help businesses identify revenue trends, understand customer behaviour, evaluate operational performance, and improve customer retention.

This project aims to transform raw e-commerce data into meaningful business insights using SQL, data modelling, and interactive Power BI dashboards.

The project uses the Olist e-commerce dataset as the basis for analysing sales, customers, products, and order fulfilment.

## Objectives

- Analyse revenue, order volume, average order value, and customer purchasing trends.
- Identify top-performing product categories and sellers.
- Understand customer purchasing frequency and segment customers based on their behaviour.
- Evaluate delivery performance and its relationship with customer review scores.
- Analyse customer retention using cohort analysis.
- Examine the order funnel from placement to delivery and review.
- Develop an interactive dashboard to support business decision-making.

## Tech Stack

| Technology | Purpose |
|---|---|
| PostgreSQL | Data storage, querying, transformations, and analytical views |
| SQL | Data analysis, business metrics, and aggregations |
| Power BI | Interactive dashboards and data visualisation |
| Power Query | Data transformation and preparation for reporting |
| DAX | Measures, calculated tables, and analytical calculations |

*Power BI, Power Query, and DAX are part of the planned dashboard implementation and should be marked as completed only once the corresponding work is built and tested.*

## Key Business Questions

### 1. Revenue & Sales Performance
- How does revenue change over time?
- How many orders are placed, and what is the average order value?
- Which customer states contribute the most revenue?
- How does monthly revenue growth change?

### 2. Product & Seller Analysis
- Which product categories generate the most revenue?
- How concentrated is revenue among the leading categories?
- Which sellers contribute the most to sales?
- How do payment methods and instalment options relate to purchasing behaviour?

### 3. Customer Behaviour & Delivery
- How frequently do customers place orders?
- What proportion of deliveries arrive late?
- How do review scores differ between late and on-time deliveries?
- Which regions experience more delivery delays?

### 4. Customer Segmentation
- Which customers generate the most revenue?
- How can customers be grouped using Recency, Frequency, and Monetary (RFM) analysis?
- Which customer segments contribute the most revenue?
- Which segments may benefit from targeted retention campaigns?

### 5. Retention & Order Funnel
- How many customers return after their first purchase?
- How does customer retention change across subsequent months?
- How many orders progress through placement, approval, shipment, delivery, and review?
- At which stages do orders drop out of the funnel?

## Analytical Approach

The project follows a structured analytics workflow:

1. **Data preparation:** Inspect source tables, understand data quality, and prepare data for analysis.
2. **SQL analysis:** Query order, customer, product, seller, payment, and review data to derive business metrics.
3. **Data modelling:** Organise analytical tables and views into fact and dimension tables for reporting.
4. **Customer analytics:** Apply RFM segmentation and cohort-based retention analysis.
5. **Visualisation:** Build interactive Power BI reports with KPIs, charts, tables, and filters.
6. **Business interpretation:** Identify meaningful trends and translate analytical findings into actionable recommendations.

## Planned Dashboard

The Power BI dashboard is organised around five analytical areas:

| Dashboard Page | Focus |
|---|---|
| Executive Overview | Revenue, orders, customers, average order value, and growth |
| Sales & Products | Category performance, seller contributions, and payment behaviour |
| Customer Behaviour & Delivery | Purchasing frequency, delivery delays, and review scores |
| RFM Segmentation | Customer segments, revenue contribution, and purchasing behaviour |
| Retention & Funnel | Cohort retention and order progression |

The dashboard will include interactive filters, consistent date selections, KPI cards, trend charts, and segment-level comparisons.

## Dataset

**Dataset:** Brazilian E-Commerce Public Dataset by Olist.

The dataset contains information related to e-commerce orders, customers, products, sellers, payments, deliveries, and customer reviews.

It can be used to study sales performance, order fulfilment, customer purchasing patterns, and retention.

Dataset source: [Olist Brazilian E-Commerce Public Dataset on Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)


## Project Goal

The goal is to develop a reproducible, business-focused analytics workflow that connects data preparation, SQL analysis, customer analytics, and interactive reporting to support better e-commerce decision-making.

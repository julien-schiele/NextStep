# **NextStep — JSON-driven Progression Engine**

**NextStep — Progress one day at a time.**  

> **A generic, JSON-driven progression engine with user tracking, designed to power multiple products from the same core backend.**  

This repository is a **portfolio project demonstrating production-grade backend design**, not a toy app. The sports example is only a **use case** — the real product is a **reusable progression platform**.

---

## 🎯 Vision & Problem Statement

Most progression applications suffer from:

* **Over-modeled databases** that are rigid and hard to evolve  
* **Hard-coded business logic** that breaks with real user behavior  

In reality:

* Users don’t follow strict calendars  
* Progress happens in **cycles**, not fixed schedules  
* Programs need **structure + flexibility**  

👉 **NextStep solves this by separating:**

* **Program definition (JSON blueprint)** — immutable, reusable, versioned  
* **User progression tracking (relational state)** — minimal, consistent, auditable  

---

## 🧠 Core Concepts

### 1️⃣ Program — *The Blueprint*

* Defined once, stored as structured JSON (`program.content`)  
* Describes sessions, cycles, rules, and progression  
* Independent of any specific user  

### 2️⃣ UserProgram — *User instance of a Program*

* Links a user to a program  
* Tracks lifecycle: `active | completed | abandoned`  

### 3️⃣ UserProgramSession — *Execution state*

* Stores what the user actually did  
* Minimal data: session index, cycle count, completion state  
* Supports analytics and product learning  

---

## 🔁 Cycles, Not Calendars

Programs are organized around **cycles**:

* A cycle defines required session types (e.g., 3 climbing + 2 flex)  
* Users choose **when** to perform sessions  
* A cycle completes only when requirements are met  
* Rest days are implicit, not enforced  

This mirrors real-world behavior and avoids brittle scheduling logic.

---

## 🏗️ Architecture Overview

* **Auth app:** UUID-based users, timestamped  
* **Program app:** Programs + Exercises + translations  
* **Tracking app:** UserProgram, UserProgramSession, UserProgramFeedback  

**Design principles:**

* Minimal relational schema  
* Business rules live in JSON + service layer  
* API-first design  
* Clear separation between blueprint and execution  

---

## 🛠️ Tech Stack

* **Backend:** Django 5.2 + Django REST Framework  
* **Auth:** JWT (SimpleJWT)  
* **API:** REST with auto-generated OpenAPI / Swagger docs (drf-yasg)  
* **Database:** PostgreSQL with JSONB-first design  
* **Driver:** Psycopg 3  
* **Infra:** Docker + Docker Compose  
* **Config:** `.env`-based configuration  
* **Testing:** Factory Boy + Faker for test data generation  
* **Identifiers:** UUID everywhere  
* **Timestamps:** UTC everywhere  

---

## 📦 Example Program (excerpt)

Programs are structured JSON interpreted server-side:

```json
{
  "version": 1,
  "sessions": [
    {
      "session": 1,
      "focus": "fitness",
      "sequences": [
        [{ "exercise": "mobility", "value": 10 }],
        [{ "exercise": "push_up", "value": 10 }, { "exercise": "squat", "value": 15 }]
      ]
    },
    {
      "session": 2,
      "focus": "climbing",
      "sequences": [
        [{ "exercise": "easy_traverse", "value": 10 }],
        [{ "exercise": "basic_boulder", "value": 8 }]
      ]
    }
  ],
  "repeat": { "cycles": 2, "progression": { "push_up": { "increment": 2, "per_cycle": 1 } } }
}
````

---

## ✅ Key Takeaways

NextStep demonstrates how to:

* Build a **flexible progression engine**
* Avoid over-modeling
* Centralize business logic in JSON/service layer
* Scale across multiple product verticals
* Design for long-term evolution

---

## 🚧 Current Status

* Backend API: **complete and functional**
* Swagger documentation: **available**
* Frontend (Next.js): **planned / in progress**
* Production-ready design, intentionally minimal in scope

---

## 🚀 Getting Started

Clone the repository with submodules

```bash
git clone --recurse-submodules https://github.com/<your-username>/NextStep.git
cd NextStep
```
Create a `.env` file at the root of the project:

```env
POSTGRES_DB=NextStep
POSTGRES_USER=username
POSTGRES_PASSWORD=password

DB_ENGINE=django.db.backends.postgresql
DB_HOST=database
DB_PORT=5432
DB_NAME=${POSTGRES_DB}
DB_USER=${POSTGRES_USER}
DB_PASSWORD=${POSTGRES_PASSWORD}

PGADMIN_DEFAULT_EMAIL=email
PGADMIN_DEFAULT_PASSWORD=password
```

Then run:

```bash
docker-compose up --build
```

API will be available via Swagger.

---

## 👤 About Me

Senior Fullstack Engineer / Tech Lead with experience in:

* Clean architecture  
* Scalable backend design  
* Product-driven engineering  
* Working in remote and international environments (startups, SMEs, ESN, and companies of 300+ employees)  

This portfolio project reflects my professional approach to reusable platform design.

---

## 📬 Contact

🔗 LinkedIn: [Julien Schiele](https://www.linkedin.com/in/julien-schiele-lead-developer-full-stack/)

Open to remote freelance missions and contract work.

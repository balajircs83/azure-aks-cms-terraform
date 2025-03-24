from fastapi import FastAPI
from pydantic import BaseModel
import pyodbc
import os

app = FastAPI()

# Customer model
class Customer(BaseModel):
    name: str
    email: str

# Database connection
def get_db_connection():
    server = os.getenv("SQL_SERVER", "cms-sql-server2025.database.windows.net")
    database = os.getenv("SQL_DB", "cms-db")
    username = os.getenv("SQL_USER", "sqladmin")
    password = os.getenv("SQL_PASSWORD", "P@ssw0rd123!")
    driver = "{ODBC Driver 18 for SQL Server}"
    conn_str = (
        f"DRIVER={driver};"
        f"SERVER={server};"
        f"DATABASE={database};"
        f"UID={username};"
        f"PWD={password};"
        "Encrypt=yes;TrustServerCertificate=no;Connection Timeout=30;"
    )
    return pyodbc.connect(conn_str)

# Create a customer
@app.post("/customers/")
def create_customer(customer: Customer):
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute(
        "INSERT INTO customers (name, email) VALUES (?, ?)",
        (customer.name, customer.email)
    )
    conn.commit()
    return {"message": "Customer created", "name": customer.name}

# Get all customers
@app.get("/customers/")
def get_customers():
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT name, email FROM customers")
    rows = cursor.fetchall()
    return [{"name": row[0], "email": row[1]} for row in rows]
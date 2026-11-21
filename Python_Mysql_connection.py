import mysql.connector

conn = mysql.connector.connect(
    host="localhost",
    user="root",
    password="Jijo_733",
    database="CompanyDB"
)

cursor = conn.cursor()

cursor.execute("SHOW TABLES")

for table in cursor.fetchall():
    print("1")
    print(table)

cursor.close()



cursor = conn.cursor()
cursor.execute("SELECT * FROM employees")

rows = cursor.fetchall()

for row in rows:
    print("2")
    print(row)

print("3")

cursor.close()
conn.close()

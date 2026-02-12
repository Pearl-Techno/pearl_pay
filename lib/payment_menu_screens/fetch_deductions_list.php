<?php
// Headers
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

// Enable error reporting for debugging
error_reporting(E_ALL);
ini_set('display_errors', 1);

// Database connection
include_once '../config/db_connect.php';

$response = array();

// Check for company_id from the GET request
if (isset($_GET['company_id'])) {
    $company_id = $_GET['company_id'];
    $employee_id = isset($_GET['employee_id']) ? $_GET['employee_id'] : null;
    $month = isset($_GET['month']) ? $_GET['month'] : null;
    $year = isset($_GET['year']) ? $_GET['year'] : null;

    // Base SQL query with a LEFT JOIN to get employee's fullname
    $sql = "SELECT 
                d.id, 
                d.employee_id, 
                e.fullname, 
                d.description, 
                d.amount, 
                d.date,
                d.company_id
            FROM 
                deductions d
            LEFT JOIN 
                employees e ON d.employee_id = e.employee_id
            WHERE 
                d.company_id = ?";

    $params = [$company_id];
    $types = "i";

    // If employee_id is provided, add it to the filter (for non-admin users)
    if ($employee_id !== null) {
        $sql .= " AND d.employee_id = ?";
        $params[] = $employee_id;
        $types .= "i"; // Assuming employee_id is an integer
    }

    // Filter by month and year if provided
    if ($month !== null && $year !== null) {
        $sql .= " AND MONTH(d.date) = ? AND YEAR(d.date) = ?";
        $params[] = $month;
        $params[] = $year;
        $types .= "ii";
    }

    $sql .= " ORDER BY d.date DESC";

    if ($stmt = $conn->prepare($sql)) {
        $stmt->bind_param($types, ...$params);
        
        if ($stmt->execute()) {
            $result = $stmt->get_result();
            $deductions = $result->fetch_all(MYSQLI_ASSOC);

            // Cast numeric types for JSON consistency
            foreach ($deductions as &$row) {
                $row['id'] = (int)$row['id'];
                $row['amount'] = (float)$row['amount'];
                $row['company_id'] = (int)$row['company_id'];
            }

            $response['status'] = 'success';
            $response['deductions'] = $deductions;
        } else {
            $response['status'] = 'error';
            $response['message'] = 'Execution failed: ' . $stmt->error;
        }
        $stmt->close();
    } else {
        $response['status'] = 'error';
        $response['message'] = 'Preparation failed: ' . $conn->error;
    }
} else {
    $response['status'] = 'error';
    $response['message'] = 'Company ID is required.';
}

echo json_encode($response);
$conn->close();
?>

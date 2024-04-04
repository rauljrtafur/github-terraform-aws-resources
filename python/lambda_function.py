# Importing necessary libraries
import json
import logging
import utils.funtions as ft

# Configuring the logger
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Lambda Main Function
def lambda_handler(event, context):
    # Gets the headers and information from the HTTP request
    headers = event.get("headers")
    http = event.get("requestContext").get("http")
    method = http.get("method")
    path = http.get("path")

    # If the method is neither GET nor POST, it returns a 405 error.
    if method not in ["GET", "POST"]:
        return {"statusCoode": 405, "body": json.dumps("Method Not Allowed")}
    
    # If the method is POST, it processes the request
    if method == "POST":
        # Gets the request body and calls the post_request function
        request_body = json.loads(event.get("body"))
        response_body = ft.post_request(path, request_body)
        
        # Returns an object with the operation status and the profile data
        return {"statusCoode": 201, "body": response_body}
        
    # If the method is neither GET nor POST, it returns a 500 error
    return {"statusCoode": 500, "body": json.dumps("Error: Method Not Allowed")}

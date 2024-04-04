# Importing necessary libraries
import json
import logging
import uuid
import base64
import io
import boto3
import gzip
from PIL import Image 

# Configuring the logger
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Function to handle POST requests
def post_request(path, body):
    # Si la ruta es "/profile", llama a la función upload_profile
    if path == "/profile":
        return upload_profile(body)
    else:
        return None

# Function to upload an image to S3
def upload_image_to_s3(image_base64, bucket_name, s3_key):
    s3 = boto3.client('s3')
    s3.put_object(Body=base64.b64decode(image_base64), Bucket=bucket_name, Key=s3_key)

# Function to upload a profile
def upload_profile(body):
    # Genera un ID de perfil único
    profile_id = str(uuid.uuid4())
    
    # Get data from the request body
    first_name = body.get("firstName")
    last_name = body.get("lastName")
    document_id = body.get("identityDocument")
    email = body.get("email")
    picture = body.get("picture")
    
    # Upload the image to S3 and get the URL
    s3_bucket_name = 'image-generate-buckets3'
    s3_key = f'{profile_id}/profile_picture'
    upload_image_to_s3(picture, s3_bucket_name, s3_key)
    picture_url = f'https://{s3_bucket_name}.s3.amazonaws.com/{s3_key}'
    
    # Create a DynamoDB client and get the table
    client = boto3.resource('dynamodb')
    table = client.Table('profile')
    
    # Insert the new profile into the table
    table.put_item(
        Item={
            'profileId': profile_id,
            'documentId': document_id,
            'firstName': first_name,
            'lastName': last_name,
            'email': email,
            'pictureURL': picture_url
        }
    )

    # Decode and open the image
    imagen_bytes = base64.b64decode(picture)
    img = Image.open(io.BytesIO(imagen_bytes))
    
    # Resize the image to 100x100
    new_img = img.resize((100, 100))
    
    # Save the new image to a buffer
    buffer = io.BytesIO()
    new_img.save(buffer, format="PNG")
    
    # Encode the new image to base64 and print it
    img_b64 = base64.b64encode(buffer.getvalue())
    print(str(img_b64))
    
    # Return an object with the operation status and profile data
    status = {"status": "successful", 
              "profileId": profile_id, 
              "name": first_name, 
              "email": email, 
              "pictureMinature":picture_url}
    
    return status

"""
Lambda function to forward emails from SES to external email addresses.
Supports mapping different recipient addresses to different forward destinations.
"""
import os
import json
import boto3
import email
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.base import MIMEBase
from email import encoders

s3 = boto3.client('s3')
ses = boto3.client('ses')

# Load forwarding mapping from environment
FORWARD_MAPPING = json.loads(os.environ['FORWARD_MAPPING'])
S3_BUCKET = os.environ['S3_BUCKET']
FROM_EMAIL = os.environ['FROM_EMAIL']

def handler(event, context):
    """
    Handle incoming SES email event and forward to configured email.
    """
    print(f"Received event: {event}")

    # Get the message ID from SES event
    message = event['Records'][0]['ses']['mail']
    message_id = message['messageId']

    # Get original recipient
    recipients = event['Records'][0]['ses']['receipt']['recipients']
    original_recipient = recipients[0] if recipients else 'unknown'

    # Determine forward destination based on recipient
    # Extract local part from email (e.g., "admin" from "admin@workfort.dev")
    local_part = original_recipient.split('@')[0] if '@' in original_recipient else 'unknown'
    forward_to = FORWARD_MAPPING.get(local_part)

    if not forward_to:
        print(f"No forwarding mapping found for {original_recipient}")
        return {'statusCode': 400, 'body': 'No forwarding mapping configured'}

    # Retrieve email from S3
    s3_key = f"incoming/{message_id}"

    try:
        response = s3.get_object(Bucket=S3_BUCKET, Key=s3_key)
        email_content = response['Body'].read()

        # Parse the email
        msg = email.message_from_bytes(email_content)

        # Create new message for forwarding
        forward_msg = MIMEMultipart()
        forward_msg['From'] = FROM_EMAIL
        forward_msg['To'] = FORWARD_TO
        forward_msg['Subject'] = f"[{original_recipient}] {msg.get('Subject', 'No Subject')}"

        # Add original headers as text
        header_text = f"""
Original From: {msg.get('From', 'Unknown')}
Original To: {original_recipient}
Original Date: {msg.get('Date', 'Unknown')}
Original Subject: {msg.get('Subject', 'No Subject')}

---

"""

        # Get the email body
        if msg.is_multipart():
            for part in msg.walk():
                content_type = part.get_content_type()
                content_disposition = str(part.get("Content-Disposition"))

                # Get email body
                if content_type == "text/plain" and "attachment" not in content_disposition:
                    body = part.get_payload(decode=True).decode(errors='ignore')
                    forward_msg.attach(MIMEText(header_text + body, 'plain'))
                elif content_type == "text/html" and "attachment" not in content_disposition:
                    body = part.get_payload(decode=True).decode(errors='ignore')
                    forward_msg.attach(MIMEText(body, 'html'))
                # Handle attachments
                elif "attachment" in content_disposition:
                    attachment = MIMEBase(part.get_content_maintype(), part.get_content_subtype())
                    attachment.set_payload(part.get_payload(decode=True))
                    encoders.encode_base64(attachment)
                    attachment.add_header('Content-Disposition', content_disposition)
                    forward_msg.attach(attachment)
        else:
            # Simple email
            body = msg.get_payload(decode=True).decode(errors='ignore')
            forward_msg.attach(MIMEText(header_text + body, 'plain'))

        # Send the forwarded email
        ses.send_raw_email(
            Source=FROM_EMAIL,
            Destinations=[forward_to],
            RawMessage={'Data': forward_msg.as_string()}
        )

        print(f"Successfully forwarded email {message_id} from {original_recipient} to {forward_to}")
        return {'statusCode': 200, 'body': 'Email forwarded successfully'}

    except Exception as e:
        print(f"Error forwarding email: {str(e)}")
        raise e

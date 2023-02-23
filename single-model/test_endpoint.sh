echo "Check if sm_variables file exist..."

test_data=$1

FILE='./sm_variables.env'
if [ -f "$FILE" ]; then
  # Source variables
  source $FILE
  # echo "Scoring URL is...$SCORING_URL"
  # echo "Endpoint key is...$KEY"

  # Make a test request
  echo "Testing out the request file..."
  curl -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" -d @$test_data $SCORING_URL
else
  echo "File does not exist..."
fi

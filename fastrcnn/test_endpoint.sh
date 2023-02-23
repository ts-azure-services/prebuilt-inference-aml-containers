echo "Check if fastrcnn_variables file exist..."
start=$SECONDS

test_data_1=$1

FILE='./fastrcnn_variables.env'
if [ -f "$FILE" ]; then
  # Source variables
  source $FILE 
  # echo "Scoring URL is...$SCORING_URL"
  # echo "Endpoint key is...$TOKEN"

  # Make a test request
  echo "Testing the fastrcnn image..."
  curl -H "Authorization: {Bearer $TOKEN}" -T $test_data_1 $SCORING_URL
else
  echo "File does not exist..."
fi
duration=$(($SECONDS- $start))
echo "\n Duration... $duration seconds"

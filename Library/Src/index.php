<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Support Page</title>
    <style>
        .form-container {
            margin-bottom: 20px;
        }
        label, input, button {
            display: block;
            margin-bottom: 10px;
        }
    </style>
</head>
<body>
    <h1>Support</h1>

    <!-- Check network connectivity form -->
    <div class="form-container">
        <h2>Check network connectivity</h2>
        <form action="index.php" method="get" onsubmit="return checkConnectivity();">
            <label for="ping">Enter URL to check status code and connectivity:</label>
            <input type="text" id="ping" name="ping" required>
            <button type="submit">Check</button>
        </form>
        <?php
            if (isset($_GET['ping'])) {
                echo "Status code: ";
                system('curl -s -o /dev/null -w "%{http_code}" ' . $_GET['ping']);
            }
        ?>
    </div>


    <script>
        function checkConnectivity() {
            var pingInput = document.getElementById("ping").value;
            if (pingInput) {
                window.location.href = "index.php?ping=" + encodeURIComponent(pingInput);
                return false; // Prevent form submission since we're using window.location.href
            }
            return true;
        }
    </script>
    <!--{AHHHZURE_Fl4g_2_WELCOME_T0_THE_SAUCE}-->
</body>
</html>

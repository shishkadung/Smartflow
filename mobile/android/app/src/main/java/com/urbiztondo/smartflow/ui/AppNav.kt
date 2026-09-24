package com.urbiztondo.smartflow.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.QrCodeScanner
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.urbiztondo.smartflow.data.AlertDto
import com.urbiztondo.smartflow.data.ApiClient
import com.urbiztondo.smartflow.data.LoginRequest
import com.urbiztondo.smartflow.data.MovementRequest
import com.urbiztondo.smartflow.data.QueueItemDto
import com.urbiztondo.smartflow.data.SessionStore
import com.urbiztondo.smartflow.data.SignupRequest
import com.urbiztondo.smartflow.data.StatsDto
import com.urbiztondo.smartflow.data.UserDto
import com.urbiztondo.smartflow.ui.theme.Sf
import com.urbiztondo.smartflow.ui.theme.SmartflowTheme
import kotlinx.coroutines.launch

@Composable
fun SmartflowRoot(sessionStore: SessionStore) {
    SmartflowTheme {
        val session by sessionStore.session.collectAsState(initial = null to null)
        val nav = rememberNavController()
        val (token, user) = session

        LaunchedEffect(token) {
            token?.let { sessionStore.restoreToken(it) }
        }

        val start = if (token != null && user != null) homeRoute(user.role) else "login"

        NavHost(navController = nav, startDestination = start) {
            composable("login") {
                LoginScreen(
                    onLogin = { u, p ->
                        val res = ApiClient.service.login(LoginRequest(u, p))
                        if (res.success && res.token != null && res.user != null) {
                            sessionStore.save(res.token, res.user)
                            nav.navigate(homeRoute(res.user.role)) {
                                popUpTo("login") { inclusive = true }
                            }
                        } else {
                            error(res.message ?: "Login failed")
                        }
                    },
                    onSignup = { nav.navigate("signup") },
                )
            }
            composable("signup") {
                SignupScreen(
                    onBack = { nav.popBackStack() },
                    onDone = { nav.navigate("login") { popUpTo("login") } },
                )
            }
            staffGraph(nav, user, sessionStore)
            headGraph(nav, user, sessionStore)
            adminGraph(nav, user, sessionStore)
        }
    }
}

private fun homeRoute(role: String) = when (role) {
    "head" -> "head/home"
    "admin" -> "admin/home"
    else -> "staff/home"
}

private fun androidx.navigation.NavGraphBuilder.staffGraph(
    nav: androidx.navigation.NavHostController,
    user: UserDto?,
    session: SessionStore,
) {
    composable("staff/home") {
        val u = user ?: return@composable
        StaffScaffold(nav, "staff/home") {
            StaffHome(u)
        }
    }
    composable("staff/scan") {
        val u = user ?: return@composable
        StaffScaffold(nav, "staff/scan") { ScannerScreen(u) }
    }
    composable("staff/alerts") {
        StaffScaffold(nav, "staff/alerts") { AlertsScreen(user!!.officeId) }
    }
    composable("staff/profile") {
        StaffScaffold(nav, "staff/profile") {
            ProfileScreen(u = user!!, onLogout = {
                kotlinx.coroutines.MainScope().launch {
                    session.clear()
                    nav.navigate("login") { popUpTo(0) }
                }
            })
        }
    }
}

private fun androidx.navigation.NavGraphBuilder.headGraph(
    nav: androidx.navigation.NavHostController,
    user: UserDto?,
    session: SessionStore,
) {
    composable("head/home") {
        HeadScaffold(nav, "head/home") { HeadHome(user!!) }
    }
    composable("head/queue") {
        HeadScaffold(nav, "head/queue") { HeadQueue(user!!.officeId) }
    }
    composable("head/alerts") {
        HeadScaffold(nav, "head/alerts") { AlertsScreen(user!!.officeId) }
    }
    composable("head/profile") {
        HeadScaffold(nav, "head/profile") {
            ProfileScreen(user!!) {
                kotlinx.coroutines.MainScope().launch {
                    session.clear()
                    nav.navigate("login") { popUpTo(0) }
                }
            }
        }
    }
}

private fun androidx.navigation.NavGraphBuilder.adminGraph(
    nav: androidx.navigation.NavHostController,
    user: UserDto?,
    session: SessionStore,
) {
    composable("admin/home") {
        AdminScaffold(nav, "admin/home") { AdminHome() }
    }
    composable("admin/users") {
        AdminScaffold(nav, "admin/users") { AdminUsers() }
    }
    composable("admin/system") {
        AdminScaffold(nav, "admin/system") { AdminSystem() }
    }
    composable("admin/profile") {
        AdminScaffold(nav, "admin/profile") {
            ProfileScreen(user!!) {
                kotlinx.coroutines.MainScope().launch {
                    session.clear()
                    nav.navigate("login") { popUpTo(0) }
                }
            }
        }
    }
}

@Composable
private fun StaffScaffold(
    nav: androidx.navigation.NavHostController,
    route: String,
    content: @Composable () -> Unit,
) {
    val items = listOf("staff/home", "staff/scan", "staff/alerts", "staff/profile")
  Scaffold(
        bottomBar = {
            NavigationBar {
                items.forEachIndexed { i, r ->
                    val labels = listOf("Home", "Scan", "Alerts", "Profile")
                    val icons = listOf(Icons.Default.Home, Icons.Default.QrCodeScanner, Icons.Default.Notifications, Icons.Default.Person)
                    NavigationBarItem(
                        selected = route == r,
                        onClick = { nav.navigate(r) { launchSingleTop = true } },
                        icon = { Icon(icons[i], null) },
                        label = { Text(labels[i]) },
                    )
                }
            }
        },
    ) { pad -> Column(Modifier.padding(pad).fillMaxSize()) { content() } }
}

@Composable
private fun HeadScaffold(nav: androidx.navigation.NavHostController, route: String, content: @Composable () -> Unit) {
    val items = listOf("head/home", "head/queue", "head/alerts", "head/profile")
    Scaffold(
        bottomBar = {
            NavigationBar {
                listOf("Home", "Queue", "Alerts", "Profile").forEachIndexed { i, label ->
                    NavigationBarItem(
                        selected = route == items[i],
                        onClick = { nav.navigate(items[i]) { launchSingleTop = true } },
                        label = { Text(label) },
                        icon = { Icon(Icons.Default.Home, null) },
                    )
                }
            }
        },
    ) { pad -> Column(Modifier.padding(pad).fillMaxSize()) { content() } }
}

@Composable
private fun AdminScaffold(nav: androidx.navigation.NavHostController, route: String, content: @Composable () -> Unit) {
    val items = listOf("admin/home", "admin/users", "admin/system", "admin/profile")
    Scaffold(
        bottomBar = {
            NavigationBar {
                listOf("Home", "Users", "System", "Profile").forEachIndexed { i, label ->
                    NavigationBarItem(
                        selected = route == items[i],
                        onClick = { nav.navigate(items[i]) { launchSingleTop = true } },
                        label = { Text(label) },
                        icon = { Icon(Icons.Default.Home, null) },
                    )
                }
            }
        },
    ) { pad -> Column(Modifier.padding(pad).fillMaxSize()) { content() } }
}

@Composable
fun SfHeader(title: String, subtitle: String? = null) {
    Column(Modifier.padding(20.dp)) {
        Text("SMARTFLOW", fontSize = 11.sp, fontWeight = FontWeight.ExtraBold, color = Sf.Muted)
        Text(title, fontSize = 22.sp, fontWeight = FontWeight.ExtraBold, color = Sf.Ink)
        subtitle?.let { Text(it, fontSize = 13.sp, color = Sf.Muted) }
    }
}

@Composable
fun LoginScreen(onLogin: suspend (String, String) -> Unit, onSignup: () -> Unit) {
    var user by remember { mutableStateOf("") }
    var pass by remember { mutableStateOf("") }
    var err by remember { mutableStateOf<String?>(null) }
    var loading by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()

    Column(Modifier.padding(24.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        SfHeader(
            "SmartFlow",
            "Municipality of Urbiztondo · document tracking & COA compliance",
        )
        OutlinedTextField(user, { user = it }, label = { Text("Username") }, modifier = Modifier.fillMaxWidth())
        OutlinedTextField(pass, { pass = it }, label = { Text("Password") }, modifier = Modifier.fillMaxWidth())
        err?.let { Text(it, color = Sf.Red) }
        Button(
            onClick = {
                scope.launch {
                    loading = true
                    err = null
                    try {
                        onLogin(user.trim(), pass)
                    } catch (e: Exception) {
                        err = e.message
                    } finally {
                        loading = false
                    }
                }
            },
            enabled = !loading,
            modifier = Modifier.fillMaxWidth(),
        ) { Text(if (loading) "Signing in…" else "Sign In") }
        OutlinedButton(onClick = onSignup, modifier = Modifier.fillMaxWidth()) {
            Text("Don't have an account? Sign up")
        }
    }
}

@Composable
fun SignupScreen(onBack: () -> Unit, onDone: () -> Unit) {
    var step by remember { mutableIntStateOf(0) }
    var name by remember { mutableStateOf("") }
    var username by remember { mutableStateOf("") }
    var email by remember { mutableStateOf("") }
    var pass by remember { mutableStateOf("") }
    var offices by remember { mutableStateOf(emptyList<com.urbiztondo.smartflow.data.OfficeDto>()) }
    var officeId by remember { mutableIntStateOf(1) }
    var role by remember { mutableStateOf("staff") }
    var err by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()

    LaunchedEffect(Unit) {
        offices = ApiClient.service.offices().offices.orEmpty()
        officeId = offices.firstOrNull()?.id ?: 1
    }

    Column(Modifier.padding(24.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        SfHeader("Create account", "Step ${step + 1} of 3")
        when (step) {
            0 -> {
                OutlinedTextField(name, { name = it }, label = { Text("Full Name") }, modifier = Modifier.fillMaxWidth())
                OutlinedTextField(username, { username = it }, label = { Text("Username") }, modifier = Modifier.fillMaxWidth())
                OutlinedTextField(email, { email = it }, label = { Text("Email (LGU)") }, modifier = Modifier.fillMaxWidth())
                OutlinedTextField(pass, { pass = it }, label = { Text("Password") }, modifier = Modifier.fillMaxWidth())
                Button(onClick = { step = 1 }, modifier = Modifier.fillMaxWidth()) { Text("Next →") }
            }
            1 -> {
                Text("Office: ${offices.joinToString { it.code }}")
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    listOf("staff" to "Employee", "head" to "Head", "admin" to "Admin").forEach { (r, label) ->
                        OutlinedButton(onClick = { role = r }) { Text(label) }
                    }
                }
                Row {
                    OutlinedButton(onClick = { step = 0 }) { Text("← Back") }
                    Spacer(Modifier.weight(1f))
                    Button(onClick = {
                        scope.launch {
                            try {
                                ApiClient.service.signup(
                                    SignupRequest(name, username, email, pass, officeId, role),
                                )
                                onDone()
                            } catch (e: Exception) {
                                err = e.message
                            }
                        }
                    }) { Text("Submit Request") }
                }
            }
        }
        err?.let { Text(it, color = Sf.Red) }
        OutlinedButton(onClick = onBack) { Text("Back to Login") }
    }
}

@Composable
fun StaffHome(user: UserDto) {
    var stats by remember { mutableStateOf<StatsDto?>(null) }
    LaunchedEffect(user.officeId) {
        stats = ApiClient.service.dashboardStats(user.officeId).stats
    }
    Column {
        SfHeader("Dashboard Overview", "Clerk · ${user.officeCode}")
        Row(Modifier.padding(horizontal = 16.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            StatBox("${stats?.inFlow ?: "—"}", "In-Flow")
            StatBox("${stats?.outFlow ?: "—"}", "Out-Flow")
            StatBox("${stats?.activeTags ?: "—"}", "QR Active")
        }
    }
}

@Composable
fun RowScope.StatBox(value: String, label: String) {
    Card(Modifier.weight(1f)) {
        Column(Modifier.padding(12.dp), horizontalAlignment = androidx.compose.ui.Alignment.CenterHorizontally) {
            Text(value, fontWeight = FontWeight.Bold, fontSize = 18.sp, color = Sf.Blue)
            Text(label, fontSize = 10.sp, color = Sf.Muted)
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ScannerScreen(user: UserDto) {
    var docId by remember { mutableStateOf("") }
    var doc by remember { mutableStateOf<com.urbiztondo.smartflow.data.DocumentDto?>(null) }
    var msg by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()

    Column(Modifier.padding(16.dp)) {
        SfHeader("Scanner module", "Mark IN / OUT at ${user.officeCode}")
        OutlinedTextField(docId, { docId = it }, label = { Text("Document ID") }, modifier = Modifier.fillMaxWidth())
        Button(onClick = {
            scope.launch {
                doc = ApiClient.service.documentShow(docId.trim()).document
            }
        }) { Text("Look up") }
        doc?.let { d ->
            Text("${d.id} · ${d.title}", fontWeight = FontWeight.Bold)
            Text("Status: ${d.currentStatus} at ${d.currentOfficeName}")
            Row(Modifier.padding(top = 12.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Button(onClick = {
                    scope.launch {
                        ApiClient.service.recordMovement(
                            MovementRequest(d.id, user.officeId, "IN", "Received"),
                        )
                        msg = "Marked IN"
                    }
                }) { Text("Mark IN") }
                OutlinedButton(onClick = {
                    scope.launch {
                        ApiClient.service.recordMovement(
                            MovementRequest(d.id, user.officeId, "OUT", "Forwarded"),
                        )
                        msg = "Marked OUT"
                    }
                }) { Text("Mark OUT") }
            }
        }
        msg?.let { Text(it, color = Sf.Green) }
    }
}

@Composable
fun AlertsScreen(officeId: Int) {
    var alerts by remember { mutableStateOf<List<AlertDto>>(emptyList()) }
    LaunchedEffect(officeId) {
        alerts = ApiClient.service.alerts(officeId).alerts.orEmpty()
    }
    LazyColumn {
        item { SfHeader("Alert Center", "Documents needing attention") }
        items(alerts) { a ->
            Card(Modifier.padding(horizontal = 16.dp, vertical = 6.dp).fillMaxWidth()) {
                Column(Modifier.padding(14.dp)) {
                    Text(a.title ?: a.documentId ?: "", fontWeight = FontWeight.Bold)
                    Text(a.detail ?: "", fontSize = 12.sp, color = Sf.Muted)
                }
            }
        }
    }
}

@Composable
fun HeadHome(user: UserDto) {
    var stats by remember { mutableStateOf<com.urbiztondo.smartflow.data.HeadStatsDto?>(null) }
    LaunchedEffect(user.officeId) {
        stats = ApiClient.service.headDashboard(user.officeId).stats
    }
    Column {
        SfHeader("Head Dashboard", user.officeName)
        Row(Modifier.padding(16.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            StatBox("${stats?.inOffice ?: 0}", "In office")
            StatBox("${stats?.overdue ?: 0}", "Overdue")
            StatBox("${stats?.avgHours ?: 0}h", "Avg time")
        }
    }
}

@Composable
fun HeadQueue(officeId: Int) {
    var queue by remember { mutableStateOf<List<QueueItemDto>>(emptyList()) }
    LaunchedEffect(officeId) {
        queue = ApiClient.service.headDashboard(officeId).queue.orEmpty()
    }
    LazyColumn {
        item { SfHeader("Document queue", "Active at office") }
        items(queue) { q ->
            Card(Modifier.padding(horizontal = 16.dp, vertical = 6.dp).fillMaxWidth()) {
                Column(Modifier.padding(14.dp)) {
                    Text("${q.documentId} · ${q.type}", fontWeight = FontWeight.Bold)
                    Text(q.meta ?: "", fontSize = 12.sp)
                    Text(q.statusPill ?: "", color = Sf.Blue, fontSize = 11.sp)
                }
            }
        }
    }
}

@Composable
fun AdminHome() {
    var dash by remember { mutableStateOf<Map<String, Any?>?>(null) }
    LaunchedEffect(Unit) {
        dash = ApiClient.service.accountantDashboard()
    }
    Column(Modifier.padding(16.dp)) {
        SfHeader("Administration Dashboard", "System overview")
        Text(dash?.toString() ?: "Loading…", fontSize = 12.sp)
    }
}

@Composable
fun AdminUsers() {
    var pending by remember { mutableStateOf<List<Map<String, Any?>>>(emptyList()) }
    val scope = rememberCoroutineScope()
    LaunchedEffect(Unit) {
        @Suppress("UNCHECKED_CAST")
        pending = ApiClient.service.signupPending()["pending"] as? List<Map<String, Any?>> ?: emptyList()
    }
    LazyColumn {
        item { SfHeader("Users & roles", "Approve sign-ups") }
        items(pending.size) { i ->
            val p = pending[i]
            Card(Modifier.padding(8.dp).fillMaxWidth()) {
                Row(Modifier.padding(12.dp), horizontalArrangement = Arrangement.SpaceBetween) {
                    Column {
                        Text("${p["username"]}", fontWeight = FontWeight.Bold)
                        Text("${p["requested_role"]} · ${p["office_name"]}", fontSize = 12.sp)
                    }
                    Button(onClick = {
                        scope.launch {
                            ApiClient.service.signupApprove(
                                mapOf("request_id" to (p["id"] as Double).toInt(), "action" to "approve"),
                            )
                        }
                    }) { Text("Approve") }
                }
            }
        }
    }
}

@Composable
fun AdminSystem() {
    var data by remember { mutableStateOf<Map<String, Any?>?>(null) }
    LaunchedEffect(Unit) { data = ApiClient.service.systemStatus() }
    Column(Modifier.padding(16.dp)) {
        SfHeader("System status", "API · MySQL")
        Text(data?.toString() ?: "…", fontSize = 12.sp)
    }
}

@Composable
fun ProfileScreen(u: UserDto, onLogout: () -> Unit) {
    Column(Modifier.padding(24.dp)) {
        SfHeader("Profile / Settings", u.role)
        Text(u.name, fontSize = 20.sp, fontWeight = FontWeight.Bold)
        Text(u.username, color = Sf.Muted)
        Text("${u.officeName} · ${u.officeCode}")
        Spacer(Modifier.height(24.dp))
        Button(onClick = onLogout, modifier = Modifier.fillMaxWidth()) { Text("Log out") }
    }
}

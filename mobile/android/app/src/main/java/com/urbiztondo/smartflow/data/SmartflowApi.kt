package com.urbiztondo.smartflow.data

import com.urbiztondo.smartflow.BuildConfig
import okhttp3.Interceptor
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import retrofit2.http.Body
import retrofit2.http.GET
import retrofit2.http.POST
import retrofit2.http.Query

interface SmartflowService {
    @POST("auth-login.php")
    suspend fun login(@Body body: LoginRequest): LoginResponse

    @POST("auth-signup.php")
    suspend fun signup(@Body body: SignupRequest): Map<String, Any?>

    @GET("offices-list.php")
    suspend fun offices(): OfficesResponse

    @GET("dashboard-stats.php")
    suspend fun dashboardStats(@Query("office_id") officeId: Int): DashboardStatsResponse

    @GET("head-dashboard.php")
    suspend fun headDashboard(@Query("office_id") officeId: Int): HeadDashboardResponse

    @GET("alerts-list.php")
    suspend fun alerts(@Query("office_id") officeId: Int): AlertsResponse

    @GET("documents-show.php")
    suspend fun documentShow(@Query("id") id: String): DocumentShowResponse

    @POST("movements-create.php")
    suspend fun recordMovement(@Body body: MovementRequest): Map<String, Any?>

    @GET("accountant-dashboard.php")
    suspend fun accountantDashboard(): Map<String, Any?>

    @GET("system-status.php")
    suspend fun systemStatus(): Map<String, Any?>

    @GET("users-list.php")
    suspend fun usersList(): Map<String, Any?>

    @GET("signup-pending-list.php")
    suspend fun signupPending(): Map<String, Any?>

    @POST("signup-approve.php")
    suspend fun signupApprove(@Body body: Map<String, Any>): Map<String, Any?>
}

object ApiClient {
    @Volatile
    var token: String? = null

    val service: SmartflowService by lazy {
        val auth = Interceptor { chain ->
            val req = chain.request().newBuilder()
            token?.let { req.header("Authorization", "Bearer $it") }
            chain.proceed(req.build())
        }
        val log = HttpLoggingInterceptor().apply {
            level = HttpLoggingInterceptor.Level.BASIC
        }
        val client = OkHttpClient.Builder()
            .addInterceptor(auth)
            .addInterceptor(log)
            .build()
        val base = BuildConfig.API_BASE.trimEnd('/') + "/"
        Retrofit.Builder()
            .baseUrl(base)
            .client(client)
            .addConverterFactory(GsonConverterFactory.create())
            .build()
            .create(SmartflowService::class.java)
    }
}

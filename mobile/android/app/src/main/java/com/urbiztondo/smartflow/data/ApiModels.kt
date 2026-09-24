package com.urbiztondo.smartflow.data

import com.google.gson.annotations.SerializedName

data class ApiResponse<T>(
    val success: Boolean? = null,
    val message: String? = null,
)

data class LoginRequest(val username: String, val password: String)

data class LoginResponse(
    val success: Boolean,
    val token: String?,
    val user: UserDto?,
    val message: String?,
)

data class UserDto(
    val id: Int,
    val name: String,
    val username: String,
    val role: String,
    @SerializedName("office_id") val officeId: Int,
    @SerializedName("office_name") val officeName: String,
    @SerializedName("office_code") val officeCode: String,
)

data class SignupRequest(
    @SerializedName("full_name") val fullName: String,
    val username: String,
    val email: String,
    val password: String,
    @SerializedName("office_id") val officeId: Int,
    @SerializedName("requested_role") val requestedRole: String,
)

data class DashboardStatsResponse(
    val success: Boolean,
    val stats: StatsDto?,
)

data class StatsDto(
    @SerializedName("in_flow") val inFlow: Int?,
    @SerializedName("out_flow") val outFlow: Int?,
    @SerializedName("active_tags") val activeTags: Int?,
)

data class HeadDashboardResponse(
    val success: Boolean,
    val stats: HeadStatsDto?,
    val queue: List<QueueItemDto>?,
)

data class HeadStatsDto(
    @SerializedName("in_office") val inOffice: Int?,
    val overdue: Int?,
    @SerializedName("avg_hours") val avgHours: Double?,
)

data class QueueItemDto(
    @SerializedName("document_id") val documentId: String,
    val title: String,
    val type: String,
    @SerializedName("status_pill") val statusPill: String?,
    val meta: String?,
)

data class AlertsResponse(
    val success: Boolean,
    val alerts: List<AlertDto>?,
)

data class AlertDto(
    @SerializedName("document_id") val documentId: String?,
    val title: String?,
    val detail: String?,
    val kind: String?,
)

data class DocumentShowResponse(
    val success: Boolean,
    val document: DocumentDto?,
)

data class DocumentDto(
    val id: String,
    val title: String,
    val type: String,
    @SerializedName("origin_office_name") val originOfficeName: String?,
    @SerializedName("current_status") val currentStatus: String?,
    @SerializedName("current_office_name") val currentOfficeName: String?,
)

data class MovementRequest(
    @SerializedName("document_id") val documentId: String,
    @SerializedName("office_id") val officeId: Int,
    val status: String,
    val remarks: String?,
)

data class OfficesResponse(
    val success: Boolean,
    val offices: List<OfficeDto>?,
)

data class OfficeDto(
    val id: Int,
    val name: String,
    val code: String,
)

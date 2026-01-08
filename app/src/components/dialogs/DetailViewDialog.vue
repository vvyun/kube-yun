<template>
    <el-dialog v-model="dialogVisible" :title="`${resourceType}详情 - ${resourceName}`" width="80%"
        :destroy-on-close="true" top="5vh">
        <div v-loading="loading">
            <el-tabs v-model="activeTab" class="detail-tabs">
                <el-tab-pane label="详情" name="detail">
                    <div class="yaml-content" v-if="!isEditing">
                        <codemirror
                            v-model="yamlContent"
                            :style="{ height: '60vh', width: '100%' }"
                            :autofocus="true"
                            :indent-with-tab="true"
                            :tab-size="2"
                            :extensions="[yamlLanguage(), readOnlyExtension]"
                        />
                    </div>
                    <div class="edit-content" v-else>
                        <codemirror
                            v-model="editedYamlContent"
                            :style="{ height: '50vh', width: '100%' }"
                            :autofocus="true"
                            :indent-with-tab="true"
                            :tab-size="2"
                            :extensions="[yamlLanguage()]"
                        />
                        <div class="edit-actions" style="margin-top: 10px; text-align: right;">
                            <el-button @click="cancelEdit">取消</el-button>
                            <el-button type="primary" @click="showDiff">查看差异</el-button>
                        </div>
                    </div>
                </el-tab-pane>
                <el-tab-pane label="差异对比" name="diff" v-if="isShowingDiff">
                    <div class="diff-content">
                        <template>
                            <Diff
                                :prev="yamlContent"
                                :current="editedYamlContent"
                                :theme='theme'
                                :height="'60vh'"
                            />
                        </template>
                    </div>
                    <div class="diff-actions" style="margin-top: 10px; text-align: right;">
                        <el-button @click="hideDiff">返回编辑</el-button>
                        <el-button type="primary" @click="applyChanges">应用</el-button>
                    </div>
                </el-tab-pane>
            </el-tabs>
        </div>

        <template #footer>
            <el-button type="primary" @click="enableEdit">编辑</el-button>
            <el-button @click="handleClose" v-if="!isEditing && !isShowingDiff">关闭</el-button>
            <el-button @click="cancelEdit" v-else-if="isEditing">取消</el-button>
            <el-button @click="hideDiff" v-else-if="isShowingDiff">返回</el-button>
        </template>
    </el-dialog>
</template>

<script setup>
import { ref, watch } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import { Codemirror } from 'vue-codemirror'
import { yaml } from '@codemirror/lang-yaml'
import { EditorView } from '@codemirror/view'
import {
    getDeploymentDetail,
    getServiceDetail,
    getConfigMapDetail,
    getIngressDetail,
    createFromYaml
} from '../../api/cluster'

const props = defineProps({
    modelValue: Boolean,
    clusterId: String,
    namespace: String,
    resourceName: String,
    resourceType: {
        type: String,
        required: true,
        validator: (value) => ['Deployment', 'Service', 'ConfigMap', 'Ingress'].includes(value)
    }
})

const emit = defineEmits(['update:modelValue'])

const dialogVisible = ref(props.modelValue)
const loading = ref(false)
const detail = ref(null)
const activeTab = ref('detail')

// 编辑相关变量
const isEditing = ref(false)
const isShowingDiff = ref(false)
const yamlContent = ref('')
const editedYamlContent = ref('')

// 获取 Codemirror 扩展
const yamlLanguage = () => yaml()
const readOnlyExtension = EditorView.editable.of(false)

// 根据资源类型获取详情的函数
const fetchDetail = async () => {
    if (!props.clusterId || !props.namespace || !props.resourceName) {
        return
    }

    loading.value = true
    try {
        let result
        switch (props.resourceType) {
            case 'Deployment':
                result = await getDeploymentDetail(props.clusterId, props.resourceName, props.namespace)
                break
            case 'Service':
                result = await getServiceDetail(props.clusterId, props.resourceName, props.namespace)
                break
            case 'ConfigMap':
                result = await getConfigMapDetail(props.clusterId, props.resourceName, props.namespace)
                break
            case 'Ingress':
                result = await getIngressDetail(props.clusterId, props.resourceName, props.namespace)
                break
            default:
                throw new Error(`不支持的资源类型: ${props.resourceType}`)
        }
        detail.value = result
        yamlContent.value = result.yaml || ''
        editedYamlContent.value = result.yaml || ''
    } catch (error) {
        console.error(`获取${props.resourceType}详情失败:`, error)
        ElMessage.error(`获取${props.resourceType}详情失败: ${error.message || error}`)
    } finally {
        loading.value = false
    }
}

// 启用编辑模式
const enableEdit = () => {
    isEditing.value = true
    editedYamlContent.value = yamlContent.value
}

// 取消编辑
const cancelEdit = () => {
    isEditing.value = false
    isShowingDiff.value = false
    activeTab.value = 'detail'
    editedYamlContent.value = yamlContent.value
}

// 显示差异对比
const showDiff = () => {
    if (yamlContent.value && editedYamlContent.value) {
        // 检查内容是否相同
        if (yamlContent.value === editedYamlContent.value) {
            ElMessageBox.confirm(
                '当前内容与原始内容相同，确定要查看差异吗？',
                '内容相同',
                {
                    confirmButtonText: '仍要查看',
                    cancelButtonText: '取消',
                    type: 'info'
                }
            ).then(() => {
                isShowingDiff.value = true
                activeTab.value = 'diff'
            }).catch(() => {
                // 用户取消
            })
        } else {
            isShowingDiff.value = true
            activeTab.value = 'diff'
        }
    } else {
        ElMessage.warning('内容尚未加载完成，请稍后再试')
    }
}

// 隐藏差异对比
const hideDiff = () => {
    isShowingDiff.value = false
    activeTab.value = 'detail'
}

// 应用更改
const applyChanges = async () => {
    try {
        // 检查内容是否相同
        if (yamlContent.value === editedYamlContent.value) {
            ElMessage.warning('内容没有变化，无需应用')
            return
        }
        
        await ElMessageBox.confirm(
            '确定要应用这些更改吗？此操作将更新资源。',
            '确认应用更改',
            {
                confirmButtonText: '应用',
                cancelButtonText: '取消',
                type: 'warning'
            }
        )
        
        // 调用应用YAML接口
        await createFromYaml(props.clusterId, editedYamlContent.value, props.namespace)
        ElMessage.success('资源更新成功')
        
        // 更新本地内容
        yamlContent.value = editedYamlContent.value
        
        // 退出编辑模式
        cancelEdit()
    } catch (error) {
        if (error !== 'cancel') {
            console.error('应用更改失败:', error)
            ElMessage.error(`应用更改失败: ${error.message || error}`)
        }
    }
}

// 监听属性变化，当打开对话框时获取详情
watch(() => props.modelValue, (newVal) => {
    dialogVisible.value = newVal
    if (newVal) {
        fetchDetail()
    } else {
        detail.value = null
        activeTab.value = 'detail'
        isEditing.value = false
        isShowingDiff.value = false
    }
})

// 监听对话框关闭事件
watch(dialogVisible, (newVal) => {
    if (!newVal) {
        emit('update:modelValue', false)
    }
})

// 关闭对话框
const handleClose = () => {
    if (isEditing.value || isShowingDiff.value) {
        ElMessageBox.confirm('您正在编辑中，确定要关闭吗？未保存的更改将会丢失。', '确认关闭', {
            confirmButtonText: '确定关闭',
            cancelButtonText: '取消',
            type: 'warning'
        }).then(() => {
            dialogVisible.value = false
        }).catch(() => {
            // 用户取消关闭
        })
    } else {
        dialogVisible.value = false
    }
}
</script>

<style scoped>
.yaml-content {
    max-height: 60vh;
    overflow: auto;
    background-color: #f5f5f5;
    padding: 15px;
    border-radius: 4px;
    font-family: 'Monaco', 'Consolas', 'Courier New', monospace;
    font-size: 12px;
    line-height: 1.5;
}

.yaml-content pre {
    margin: 0;
    white-space: pre-wrap;
    word-wrap: break-word;
}

.metadata-content {
    padding: 20px 0;
}

.metadata-content h4 {
    margin: 15px 0 10px 0;
    font-size: 16px;
    font-weight: bold;
}

.label-tag {
    margin-right: 8px;
    margin-bottom: 8px;
}

.annotations-section {
    margin-top: 20px;
}

.annotation-value {
    word-break: break-all;
    max-width: 400px;
    display: inline-block;
}

.detail-tabs :deep(.el-tabs__content) {
    padding: 20px 0;
}

.diff-content {
    height: 60vh;
    overflow: auto;
    position: relative;
}

.edit-content {
    height: 60vh;
}

.cm-editor {
    border: 1px solid #ddd;
    border-radius: 4px;
}
</style>
<template>
  <div>
    <el-breadcrumb separator-class="el-icon-arrow-right">
      <el-breadcrumb-item :to="{ path: '/home' }">root</el-breadcrumb-item>
      <el-breadcrumb-item>1</el-breadcrumb-item>
      <el-breadcrumb-item>2</el-breadcrumb-item>
    </el-breadcrumb>
    <el-card class="box-card">
      <el-row :gutter="20">
        <el-col :span="9">
          <el-input placeholder="Please Input" class="input-with-select" v-model="queryInfo.query" clearable
          >
            <el-button slot="append" icon="el-icon-search"></el-button>
          </el-input>
        </el-col>
        <el-col :span="5">
          <el-button type="primary" @click="addDialogVisible = true">Add</el-button>
        </el-col>
      </el-row>


      <el-table :data="machineList" border stripe v-loading="loading"
                element-loading-text="Loading data"
                element-loading-spinner="el-icon-loading"
                element-loading-background="rgba(255, 255, 255, 0.8)">
        <el-table-column type="index">
        </el-table-column>

        <el-table-column label="Instance Tag" prop="instance_tag" width="160px">
          <template slot-scope="scope">
            <el-tag
              closable
              type='success'
              @close="tagHandleClose(scope.row.instance_tag)">
              {{ scope.row.instance_tag }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="User" prop="user_name" width="130px"></el-table-column>
        <el-table-column label="Machine" prop="info" width="260px">
          <template slot-scope="scope">
            <ul>
              <li>M1 Public IP :{{ scope.row.info.public_ip }}</li>
              <li>M1 Private IP :{{ scope.row.info.private_ip }}</li>
              <li>Cluster Status :{{ scope.row.info.status }}</li>
            </ul>


          </template>
        </el-table-column>
        <el-table-column label="Monitor Service">
          <!--          父组件向子组件传值,scope.row -&ndash;&gt; machineList-->
          <template slot-scope="scope">
            <div v-for="(item,  i) in scope.row.checkList" :key="i">
              <span>{{ item }}</span>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="Crash Stacktrace" prop="crash_stacktrace">
          <template slot-scope="scope">
            <el-collapse>
              <el-collapse-item
                v-for="(value,key,index) in scope.row.crash_stacktrace"
                :title="key"
                :name="key"
                :key="index">

                <div
                  v-for="(sub_value,sub_index) in value"
                  :key="sub_index"
                  @click="showCrashDetail(sub_value)"
                >
                  crash : {{ sub_index }}
                </div>

              </el-collapse-item>
            </el-collapse>
          </template>
        </el-table-column>


        <el-table-column label="Comment" width="300px" align="center">
          <template slot-scope="scope">
            <el-input
              type="textarea"
              :autosize="{ minRows: 2, maxRows: 4}"
              placeholder="Please input"
              v-model="scope.row.comment_msg"
              @blur="inputBlur(scope.row.identify,scope.row.comment_msg)">
            </el-input>
          </template>
        </el-table-column>


      </el-table>
    </el-card>
    <!--  添加新监控集群对话框-->
    <el-dialog
      title="Add Cluster Monitor"
      :visible.sync="addDialogVisible"
      width="30%"
      @close="addDialogClosed"
    >
      <!--      新增内容主体区-->
      <el-form :model="addForm"  ref="addFormRef" :rules="addFormRules" label-width="150px" :status-icon="true">


        <template>
          <el-tabs v-model="activeName" @tab-click="handleClick">
            <el-tab-pane label="Cloud Instance" name="ci">
              <el-form-item label="User Name" prop="user_name">
                <el-input v-model="addForm.user_name"></el-input>
              </el-form-item>

              <el-form-item label="Instance Tag" prop="instance_tag">
                <el-input v-model="addForm.instance_tag"></el-input>
              </el-form-item>
              <el-form-item label="Monitor service" prop="checkList">
                <template>
                  <el-checkbox-group v-model="addForm.checkList">
                    <el-checkbox label="gpe" disabled></el-checkbox>
                    <el-checkbox label="gse" disabled></el-checkbox>
                  </el-checkbox-group>
                </template>
              </el-form-item>
            </el-tab-pane>


            <el-tab-pane label="Inner Instance" name="ii">
              <el-form-item label="IP" prop="instance_tag">
                <el-input v-model="addForm.instance_tag"></el-input>
              </el-form-item>
              <el-form-item label="Login User" prop="user_name">
                <el-input v-model="addForm.user_name"></el-input>
              </el-form-item>
              <el-form-item label="Login Password" prop="password">
              <el-input v-model="addForm.password" show-password></el-input>
              </el-form-item>

              <el-form-item label="Monitor service" prop="checkList">
                <template>
                  <el-checkbox-group v-model="addForm.checkList">
                    <el-checkbox label="gpe" disabled></el-checkbox>
                    <el-checkbox label="gse" disabled></el-checkbox>
                  </el-checkbox-group>
                </template>
              </el-form-item>
            </el-tab-pane>
          </el-tabs>
        </template>


      </el-form>
      <span slot="footer" class="dialog-footer">
    <el-button @click="addDialogVisible = false">cancel</el-button>
    <el-button type="primary" @click="addCluster">Confirm</el-button>
  </span>
    </el-dialog>


    <!--    堆栈详细信息表-->
    <el-dialog title="Crash Stacktrace" :visible.sync="crashStacktraceVisible" width="50%">
      <el-form :model="crashDetail" ref="editFormRef" label-width="70px">
        <el-form-item label="Machine">
          {{ crashDetail.machine }}
        </el-form-item>
        <el-form-item label="File Path">
          {{ crashDetail.path }}
        </el-form-item>
        <el-form-item label="Status" style="text-align: left">
          <el-radio-group v-model="radio">
            <el-radio :label="3">Known Issue</el-radio>
            <el-radio :label="6">New Issue</el-radio>
            <el-radio :label="9">No Select</el-radio>
          </el-radio-group>
        </el-form-item>

      </el-form>
      <h2 align="center">Crash Detail</h2>
<!--      <div style="width: 200px;">-->
<!--          <pre>-->
<!--            {{ crashDetail.data }}-->
<!--          </pre>-->
<!--      </div>-->

      <div style="white-space: pre-wrap" >
          <span>
            {{ crashDetail.data }}
          </span>
      </div>

      <span slot="footer" class="dialog-footer">
        <el-button @click="crashStacktraceVisible = false">Close</el-button>
      </span>
    </el-dialog>


  </div>
</template>

<script>
export default {
  data() {
    return {
      radio: 9,
      activeName: 'ci', //新增monitor中的选择用cloud instance 还是 inner instance
      checkedGpe: true,
      loading: true, //加载时loading状态
      addDialogVisible: false,// 新增监控tag
      crashStacktraceVisible: false,// 堆栈信息框显示
      addForm: {
        user_name: '',
        instance_tag: '',
        password:'',
        checkList: ["gpe"],
      },
      crashDetail: {
        data: "",
        machine: "",
        path: ""
      },
      queryInfo: {
        owner: 'all', // 要查询的用户名
        pagenum: 1,//当前页数
        pagesize: 10,//每页显示数目
      },
      machineList: [],
      // 新增表单的验证
      addFormRules: {
        user_name: [
          {required: true, message: "input username", trigger: 'blur'},
          {min: 3, max: 15, message: "user_name limit 3-15 length ", trigger: 'blur'}
        ],
        password: [
          {required: true, message: "input password", trigger: 'blur'},
          {min: 3, max: 15, message: "password limit 3-15 length ", trigger: 'blur'}
        ],
        instance_tag: [
          {required: true, message: "input instance_tag", trigger: 'blur'},
          {min: 3, max: 20, message: "instance_tag limit 3-20 length ", trigger: 'blur'}
        ],
      }
    }


  },
  created() {
    this.getCluster()
  },
  methods: {

    //监听新增monitor切换时候的事件
    handleClick(tab, event){
      console.log(tab, event);
      this.$refs.addFormRef.resetFields()//清空表单数据
    },

    //监听Comment的输入框blur事件
    inputBlur(identify, msg) {
      this.putTableData(identify, msg)

    },

    //监听对话框关闭事件
    addDialogClosed() {
      this.$refs.addFormRef.resetFields()//清空表单数据
    },

    async putTableData(identify, msg) {
      const sendData = {
        "identify": identify,
        "data": {
          "comment_msg": msg,
        }
      }
      const {data: res} = await this.$http.put('monitor/crash', {params: {"comment_tag": sendData}}) //发起put请求更新数据
      if (res.code !== 200) {
        return this.$message.error("Update Comment failed")
      } else {
        this.$message.success("Update Comment successfully")
      }
      // await this.getCluster()
    },

    //根据标签删除
    async tagHandleClose(tag_name) {

      const confirmResult = await this.$confirm('Are you sure to delete this cluster monitor?', 'Tips', {
        confirmButtonText: 'Yes',
        cancelButtonText: 'cancel',
        type: 'warning'
      }).catch(err => err)

      if (confirmResult !== 'confirm') {
        return this.$message.info("Cancel")
      } else {
        const {data: res} = await this.$http.delete('monitor/crash', {params: {"delete_tag": tag_name}})
        if (res.code !== 200) {
          return this.$message.error("delete failed")
        } else {
          this.$message.success("delete success")
          await this.getCluster()
        }
      }


    },
    showCrashDetail(get_data) {
      this.crashDetail = get_data
      this.crashStacktraceVisible = true
    },
    // 新增监控
    async addCluster() {

      if (this.addForm.password===''){
        delete this.addForm["password"]
      }
      const {data: res} = await this.$http.post('monitor/crash', {params: this.addForm})
      if (res.code !== 200) {
        this.addDialogVisible = false
        return this.$message.error("add failed")
      } else {
        // this.machineList = res.data.get_data
        this.$message.success("add success")
        this.addDialogVisible = false
        await this.getCluster()
      }
    },
    async getCluster() {
      this.loading = true
      const {data: res} = await this.$http.get('monitor/crash', {params: this.queryInfo})
      if (res.code !== 200) {
        this.loading = false
        return this.$message.error("get failed")
      } else {
        this.loading = false
        this.machineList = res.data.get_data
        return this.$message.success("get success")
      }
    }
  }
}
</script>

<style lang="less" scoped>
.el-pagination {
  text-align: right;

}

.el-form-item {
  margin-bottom: 0;
  text-align: left
}

.el-form-item__label {
  text-align: left
}

.el-input {
  margin-left: 0;
}

i {
  font-size: 30px
}

.li {
  margin-left: 0;
}
</style>

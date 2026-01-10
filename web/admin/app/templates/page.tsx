"use client"

import { useState, useEffect } from "react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Checkbox } from "@/components/ui/checkbox"
import {
    Dialog,
    DialogContent,
    DialogDescription,
    DialogFooter,
    DialogHeader,
    DialogTitle,
    DialogTrigger,
} from "@/components/ui/dialog"
import {
    Select,
    SelectContent,
    SelectItem,
    SelectTrigger,
    SelectValue,
} from "@/components/ui/select"
import { Plus, Trash2, Pencil, Copy, Users, Clock, Database, Layers } from "lucide-react"

export default function TemplatesPage() {
    const [templates, setTemplates] = useState([])
    const [groups, setGroups] = useState([])
    const [addDialogOpen, setAddDialogOpen] = useState(false)
    const [editDialogOpen, setEditDialogOpen] = useState(false)
    const [selectedTemplate, setSelectedTemplate] = useState<any>(null)

    // Form Data
    const [formData, setFormData] = useState({
        name: "",
        data_limit_gb: 0,
        expire_days: 0,
        username_prefix: "",
        username_suffix: "",
        status: "active",
        group_ids: [] as number[],
        is_disabled: false
    })

    const fetchTemplates = () => {
        fetch('/api/user_templates', { cache: 'no-store' })
            .then(res => res.json())
            .then(data => setTemplates(data || []))
            .catch(err => console.error(err))
    }

    const fetchGroups = () => {
        fetch('/api/groups', { cache: 'no-store' })
            .then(res => res.json())
            .then(data => setGroups(data || []))
            .catch(err => console.error(err))
    }

    useEffect(() => {
        fetchTemplates()
        fetchGroups()
    }, [])

    const handleCreate = async () => {
        await fetch('/api/user_templates', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                name: formData.name,
                data_limit: formData.data_limit_gb * 1024 * 1024 * 1024,
                expire_duration: formData.expire_days * 24 * 60 * 60,
                username_prefix: formData.username_prefix,
                username_suffix: formData.username_suffix,
                status: formData.status,
                group_ids: formData.group_ids,
                is_disabled: formData.is_disabled
            })
        })
        setAddDialogOpen(false)
        resetForm()
        fetchTemplates()
    }

    const handleUpdate = async () => {
        await fetch('/api/user_templates', {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                id: selectedTemplate.id,
                name: formData.name,
                data_limit: formData.data_limit_gb * 1024 * 1024 * 1024,
                expire_duration: formData.expire_days * 24 * 60 * 60,
                username_prefix: formData.username_prefix,
                username_suffix: formData.username_suffix,
                status: formData.status,
                group_ids: formData.group_ids,
                is_disabled: formData.is_disabled
            })
        })
        setEditDialogOpen(false)
        fetchTemplates()
    }

    const handleDelete = async (id: number) => {
        if (confirm("Delete this template?")) {
            await fetch(`/api/user_templates?id=${id}`, { method: 'DELETE' })
            fetchTemplates()
        }
    }

    const resetForm = () => {
        setFormData({
            name: "",
            data_limit_gb: 0,
            expire_days: 0,
            username_prefix: "",
            username_suffix: "",
            status: "active",
            group_ids: [],
            is_disabled: false
        })
    }

    const openEdit = (t: any) => {
        setSelectedTemplate(t)
        setFormData({
            name: t.name,
            data_limit_gb: t.data_limit / (1024 * 1024 * 1024),
            expire_days: t.expire_duration / (24 * 60 * 60),
            username_prefix: t.username_prefix,
            username_suffix: t.username_suffix,
            status: t.status,
            group_ids: t.group_ids || [],
            is_disabled: t.is_disabled
        })
        setEditDialogOpen(true)
    }

    const toggleGroupSelection = (gid: number) => {
        setFormData(prev => {
            const exists = prev.group_ids.includes(gid)
            if (exists) {
                return { ...prev, group_ids: prev.group_ids.filter(id => id !== gid) }
            } else {
                return { ...prev, group_ids: [...prev.group_ids, gid] }
            }
        })
    }

    return (
        <div className="flex-1 space-y-4 p-8 pt-6">
            <div className="flex items-center justify-between">
                <div>
                    <h2 className="text-3xl font-bold tracking-tight">User Templates</h2>
                    <p className="text-zinc-400">Pre-configured settings for quick user creation.</p>
                </div>
                <Dialog open={addDialogOpen} onOpenChange={setAddDialogOpen}>
                    <DialogTrigger asChild>
                        <Button className="bg-emerald-600 hover:bg-emerald-700 text-white" onClick={resetForm}>
                            <Plus className="mr-2 h-4 w-4" /> Create Template
                        </Button>
                    </DialogTrigger>
                    <DialogContent className="bg-zinc-900 border-zinc-800 text-white max-w-lg">
                        <DialogHeader>
                            <DialogTitle>Create User Template</DialogTitle>
                            <DialogDescription className="text-zinc-400">
                                Set default values for new users.
                            </DialogDescription>
                        </DialogHeader>
                        <div className="grid gap-4 py-4">
                            <div className="grid gap-2">
                                <Label>Template Name</Label>
                                <Input className="bg-zinc-800 border-zinc-700" value={formData.name}
                                    onChange={(e) => setFormData({ ...formData, name: e.target.value })} placeholder="e.g. 1 Month Premium" />
                            </div>

                            <div className="grid grid-cols-2 gap-4">
                                <div className="grid gap-2">
                                    <Label>Data Limit (GB)</Label>
                                    <Input type="number" className="bg-zinc-800 border-zinc-700" value={formData.data_limit_gb}
                                        onChange={(e) => setFormData({ ...formData, data_limit_gb: parseFloat(e.target.value) })} />
                                    <p className="text-[10px] text-zinc-500">0 = Unlimited</p>
                                </div>
                                <div className="grid gap-2">
                                    <Label>Duration (Days)</Label>
                                    <Input type="number" className="bg-zinc-800 border-zinc-700" value={formData.expire_days}
                                        onChange={(e) => setFormData({ ...formData, expire_days: parseFloat(e.target.value) })} />
                                    <p className="text-[10px] text-zinc-500">0 = Unlimited</p>
                                </div>
                            </div>

                            <div className="grid grid-cols-2 gap-4">
                                <div className="grid gap-2">
                                    <Label>Username Prefix</Label>
                                    <Input className="bg-zinc-800 border-zinc-700" value={formData.username_prefix}
                                        onChange={(e) => setFormData({ ...formData, username_prefix: e.target.value })} placeholder="e.g. vip_" />
                                </div>
                                <div className="grid gap-2">
                                    <Label>Username Suffix</Label>
                                    <Input className="bg-zinc-800 border-zinc-700" value={formData.username_suffix}
                                        onChange={(e) => setFormData({ ...formData, username_suffix: e.target.value })} placeholder="e.g. _2024" />
                                </div>
                            </div>

                            <div className="grid gap-2">
                                <Label>Initial Status</Label>
                                <Select value={formData.status} onValueChange={(val) => setFormData({ ...formData, status: val })}>
                                    <SelectTrigger className="bg-zinc-800 border-zinc-700">
                                        <SelectValue />
                                    </SelectTrigger>
                                    <SelectContent className="bg-zinc-800 border-zinc-700 text-white">
                                        <SelectItem value="active">Active</SelectItem>
                                        <SelectItem value="on_hold">On Hold</SelectItem>
                                    </SelectContent>
                                </Select>
                            </div>

                            <div className="grid gap-2">
                                <Label>Assign Groups</Label>
                                <div className="flex flex-wrap gap-2 p-3 border border-zinc-700 rounded-md bg-zinc-800/50">
                                    {groups.map((g: any) => (
                                        <div key={g.id} className="flex items-center space-x-2">
                                            <Checkbox
                                                id={`g-${g.id}`}
                                                checked={formData.group_ids.includes(g.id)}
                                                onCheckedChange={() => toggleGroupSelection(g.id)}
                                            />
                                            <Label htmlFor={`g-${g.id}`} className="text-sm cursor-pointer">{g.name}</Label>
                                        </div>
                                    ))}
                                    {groups.length === 0 && <span className="text-xs text-zinc-500">No groups available.</span>}
                                </div>
                            </div>
                        </div>
                        <DialogFooter>
                            <Button onClick={handleCreate} className="bg-emerald-600 hover:bg-emerald-700">Create Template</Button>
                        </DialogFooter>
                    </DialogContent>
                </Dialog>
            </div>

            <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
                {templates.map((t: any) => (
                    <Card key={t.id} className="bg-zinc-900 border-zinc-800 text-white">
                        <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                            <CardTitle className="text-sm font-medium flex items-center gap-2">
                                <Copy className="h-4 w-4 text-emerald-500" />
                                {t.name}
                            </CardTitle>
                            <div className="flex gap-1">
                                <Button variant="ghost" size="icon" className="h-7 w-7 hover:bg-zinc-800" onClick={() => openEdit(t)}>
                                    <Pencil className="h-4 w-4 text-zinc-400" />
                                </Button>
                                <Button variant="ghost" size="icon" className="h-7 w-7 hover:bg-zinc-800" onClick={() => handleDelete(t.id)}>
                                    <Trash2 className="h-4 w-4 text-red-500" />
                                </Button>
                            </div>
                        </CardHeader>
                        <CardContent className="space-y-3 pt-2">
                            <div className="grid grid-cols-2 gap-2 text-xs">
                                <div className="flex items-center gap-2 text-zinc-400">
                                    <Database className="h-3 w-3" />
                                    <span>{t.data_limit === 0 ? "Unlimited" : (t.data_limit / 1073741824).toFixed(1) + " GB"}</span>
                                </div>
                                <div className="flex items-center gap-2 text-zinc-400">
                                    <Clock className="h-3 w-3" />
                                    <span>{t.expire_duration === 0 ? "Unlimited" : (t.expire_duration / 86400).toFixed(0) + " Days"}</span>
                                </div>
                            </div>

                            <div className="flex items-center gap-2 text-xs text-zinc-500">
                                <span className="font-mono bg-zinc-800 px-1 rounded">
                                    {t.username_prefix}USER{t.username_suffix}
                                </span>
                            </div>

                            <div className="space-y-1">
                                <div className="flex items-center gap-1 text-xs text-zinc-500">
                                    <Layers className="h-3 w-3" /> Groups:
                                </div>
                                <div className="flex flex-wrap gap-1">
                                    {t.group_ids && t.group_ids.length > 0 ? (
                                        t.group_ids.map((gid: number) => {
                                            const g = groups.find((grp: any) => grp.id === gid)
                                            return g ? (
                                                <Badge key={gid} variant="outline" className="border-zinc-700 text-zinc-400 text-[10px]">
                                                    {g.name}
                                                </Badge>
                                            ) : null
                                        })
                                    ) : (
                                        <span className="text-[10px] text-zinc-600 italic">None</span>
                                    )}
                                </div>
                            </div>
                        </CardContent>
                    </Card>
                ))}
            </div>

            {/* Edit Dialog - Almost identical to Create, could extract component */}
            <Dialog open={editDialogOpen} onOpenChange={setEditDialogOpen}>
                <DialogContent className="bg-zinc-900 border-zinc-800 text-white max-w-lg">
                    <DialogHeader>
                        <DialogTitle>Edit Template</DialogTitle>
                    </DialogHeader>
                    <div className="grid gap-4 py-4">
                        <div className="grid gap-2">
                            <Label>Template Name</Label>
                            <Input className="bg-zinc-800 border-zinc-700" value={formData.name}
                                onChange={(e) => setFormData({ ...formData, name: e.target.value })} />
                        </div>
                        <div className="grid grid-cols-2 gap-4">
                            <div className="grid gap-2">
                                <Label>Data Limit (GB)</Label>
                                <Input type="number" className="bg-zinc-800 border-zinc-700" value={formData.data_limit_gb}
                                    onChange={(e) => setFormData({ ...formData, data_limit_gb: parseFloat(e.target.value) })} />
                            </div>
                            <div className="grid gap-2">
                                <Label>Duration (Days)</Label>
                                <Input type="number" className="bg-zinc-800 border-zinc-700" value={formData.expire_days}
                                    onChange={(e) => setFormData({ ...formData, expire_days: parseFloat(e.target.value) })} />
                            </div>
                        </div>
                        <div className="grid grid-cols-2 gap-4">
                            <div className="grid gap-2">
                                <Label>Username Prefix</Label>
                                <Input className="bg-zinc-800 border-zinc-700" value={formData.username_prefix}
                                    onChange={(e) => setFormData({ ...formData, username_prefix: e.target.value })} />
                            </div>
                            <div className="grid gap-2">
                                <Label>Username Suffix</Label>
                                <Input className="bg-zinc-800 border-zinc-700" value={formData.username_suffix}
                                    onChange={(e) => setFormData({ ...formData, username_suffix: e.target.value })} />
                            </div>
                        </div>
                        <div className="grid gap-2">
                            <Label>Initial Status</Label>
                            <Select value={formData.status} onValueChange={(val) => setFormData({ ...formData, status: val })}>
                                <SelectTrigger className="bg-zinc-800 border-zinc-700">
                                    <SelectValue />
                                </SelectTrigger>
                                <SelectContent className="bg-zinc-800 border-zinc-700 text-white">
                                    <SelectItem value="active">Active</SelectItem>
                                    <SelectItem value="on_hold">On Hold</SelectItem>
                                </SelectContent>
                            </Select>
                        </div>
                        <div className="grid gap-2">
                            <Label>Assign Groups</Label>
                            <div className="flex flex-wrap gap-2 p-3 border border-zinc-700 rounded-md bg-zinc-800/50">
                                {groups.map((g: any) => (
                                    <div key={g.id} className="flex items-center space-x-2">
                                        <Checkbox
                                            id={`ge-${g.id}`}
                                            checked={formData.group_ids.includes(g.id)}
                                            onCheckedChange={() => toggleGroupSelection(g.id)}
                                        />
                                        <Label htmlFor={`ge-${g.id}`} className="text-sm cursor-pointer">{g.name}</Label>
                                    </div>
                                ))}
                            </div>
                        </div>
                    </div>
                    <DialogFooter>
                        <Button onClick={handleUpdate} className="bg-emerald-600 hover:bg-emerald-700">Save Changes</Button>
                    </DialogFooter>
                </DialogContent>
            </Dialog>
        </div>
    )
}
